import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Api, AvatarResult } from '../common/Api';
import { Store } from '../store/Store';
import { Theme } from '../common/Theme';

// 性别选项（单选）
const GENDERS: string[] = ['男', '女'];

// 编辑个人资料：头像 / 昵称 / 性别 / 生日，点击“保存”后写回 Store 并持久化
@Entry
@Component
struct ProfileEditPage {
  // 深色模式开关：双向绑定 AppStorage，切换后页面配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;
  // 表单快照：进入页面时从 Store 读取，点“保存”后统一写回
  @State nickname: string = '';
  @State gender: string = '';
  @State birthday: string = '';
  @State avatar: string = '';
  @State saving: boolean = false;
  private store: Store = Store.get();

  aboutToAppear(): void {
    this.nickname = this.store.nickname;
    this.gender = this.store.gender;
    this.birthday = this.store.birthday;
    this.avatar = this.store.avatar;
  }

  // 从系统相册选择头像：相册 URI 仅临时可读，复制进应用沙箱后保存路径
  private async pickAvatar(): Promise<void> {
    const picker = new photoAccessHelper.PhotoViewPicker();
    const result = await picker.select({
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    });
    if (result.photoUris.length === 0) {
      return;
    }
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const dest = `${ctx.filesDir}/avatar_${Date.now()}.jpg`;
      const src = fs.openSync(result.photoUris[0], fs.OpenMode.READ_ONLY);
      try {
        fs.copyFileSync(src.fd, dest);
        // 相册选择器返回时页面可能重新走 aboutToAppear，
        // 只改 @State 会被 Store 里的旧头像覆盖；这里立即持久化到 Store。
        this.avatar = dest;
        await this.store.updateProfile(this.store.nickname, this.store.gender, this.store.birthday, dest);
      } finally {
        fs.closeSync(src);
      }
    } catch (err) {
      console.error(`pickAvatar failed: ${err}`);
      promptAction.showToast({ message: '头像设置失败，请重试' });
    }
  }

  // 生日选择弹窗（默认 2000-1-1，可选范围 1900-1-1 至今天）
  private showBirthdayPicker(): void {
    DatePickerDialog.show({
      start: new Date('1900-1-1'),
      end: new Date(),
      selected: this.birthday !== '' ? new Date(this.birthday) : new Date('2000-1-1'),
      onDateAccept: (value: Date) => {
        this.birthday = `${value.getFullYear()}-${value.getMonth() + 1}-${value.getDate()}`;
      }
    });
  }

  // 头像既可能是本地沙箱路径，也可能是后端返回的 http(s) URL
  private avatarUri(): string {
    if (this.avatar.startsWith('http://') || this.avatar.startsWith('https://') || this.avatar.startsWith('file://')) {
      return this.avatar;
    }
    if (this.avatar.startsWith('/media/')) {
      return Api.resolveMediaUrl(this.avatar);
    }
    return `file://${this.avatar}`;
  }

  // 选完头像后先上传到服务器，返回服务器 URL；失败返回空串
  private async uploadAvatarIfNeeded(): Promise<string> {
    if (this.avatar === '' || this.avatar.startsWith('http://') || this.avatar.startsWith('https://')) {
      return this.avatar;
    }
    // 后端返回的相对地址（/media/avatars/...）已经是服务器头像，不需要再上传
    if (this.avatar.startsWith('/media/')) {
      return this.avatar;
    }
    if (this.store.token === '') {
      promptAction.showToast({ message: '请先登录后再上传头像' });
      return '';
    }
    const localPath = this.avatar.startsWith('file://')
      ? this.avatar.substring(7)
      : this.avatar;
    try {
      const stat = fs.statSync(localPath);
      if (stat.size <= 0 || stat.size > 2 * 1024 * 1024) {
        promptAction.showToast({ message: '头像需小于 2MB' });
        return '';
      }
      const file = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(stat.size);
      const read = fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      if (read <= 0) {
        promptAction.showToast({ message: '读取头像失败' });
        return '';
      }
      const bytes: ArrayBuffer = read === stat.size ? buffer : buffer.slice(0, read);
      const result: AvatarResult = await Api.uploadAvatar(this.store.token, bytes);
      if (!result.ok) {
        promptAction.showToast({ message: result.message });
        return '';
      }
      return result.avatar;
    } catch (err) {
      console.error(`uploadAvatar failed: ${err}`);
      promptAction.showToast({ message: '头像上传失败，请重试' });
      return '';
    }
  }

  // 保存资料：昵称非空校验后写回 Store
  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    const name = this.nickname.trim();
    if (name === '') {
      promptAction.showToast({ message: '昵称不能为空' });
      return;
    }
    this.saving = true;
    const avatar = await this.uploadAvatarIfNeeded();
    if (this.avatar !== '' && avatar === '') {
      // 选过头像但上传失败：不保存半成品资料
      this.saving = false;
      return;
    }
    this.avatar = avatar;
    await this.store.updateProfile(name, this.gender, this.birthday, this.avatar);
    this.saving = false;
    promptAction.showToast({ message: '资料已保存' });
    router.back();
  }

  // 头像区：已选图片或占位图标，右下角相机角标提示可更换
  @Builder
  AvatarPicker() {
    Stack() {
      if (this.avatar !== '') {
        Image(this.avatarUri())
          .width(88)
          .height(88)
          .borderRadius(44)
          .objectFit(ImageFit.Cover)
      } else {
        Column() {
          SymbolGlyph($r('sys.symbol.person'))
            .fontSize(40)
            .fontColor([Color.White])
        }
        .width(88)
        .height(88)
        .borderRadius(44)
        .backgroundColor(Theme.accent(this.isDark))
        .justifyContent(FlexAlign.Center)
      }
      Column() {
        SymbolGlyph($r('sys.symbol.camera'))
          .fontSize(14)
          .fontColor([Color.White])
      }
      .width(28)
      .height(28)
      .borderRadius(14)
      .backgroundColor(Theme.accent(this.isDark))
      .border({ width: 2, color: Theme.card(this.isDark) })
      .justifyContent(FlexAlign.Center)
      .align(Alignment.BottomEnd)
    }
    .width(88)
    .height(88)
  }

  build() {
    Column() {
      // 顶栏：返回 + 标题
      Row() {
        Column() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor([Theme.ink(this.isDark)])
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          router.back();
        })
        Text('编辑资料')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink(this.isDark))
          .margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })

      Scroll() {
        Column() {
          // 头像：点击唤起系统相册选图
          Column() {
            Text('头像')
              .fontSize(13)
              .fontColor(Theme.inkSecondary(this.isDark))
              .width('100%')    
            this.AvatarPicker()
            Text('点击更换头像')
              .fontSize(12)
              .fontColor(Theme.inkTertiary(this.isDark))
              .margin({ top: 8 })
          }
          .backgroundColor(Theme.glass(this.isDark))
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: Theme.glassBorder(this.isDark) })
          .borderRadius(18)
          .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
          .padding(20)
          .width('100%')
          .margin({ top: 12 })
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .onClick(() => {
            this.pickAvatar();
          })

          // 昵称
          Column() {
            Text('昵称')
              .fontSize(13)
              .fontColor(Theme.inkSecondary(this.isDark))
              .width('100%')
            TextInput({ placeholder: '请输入昵称', text: this.nickname })
              .height(46)
              .fontSize(15)
              .fontColor(Theme.ink(this.isDark))
              .placeholderColor(Theme.inkTertiary(this.isDark))
              .backgroundColor(Theme.bg(this.isDark))
              .borderRadius(12)
              .padding({ left: 14, right: 14 })
              .margin({ top: 12 })
              .maxLength(20)
              .onChange((v: string) => {
                this.nickname = v;
              })
          }
          .backgroundColor(Theme.glass(this.isDark))
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: Theme.glassBorder(this.isDark) })
          .borderRadius(18)
          .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
          .padding(20)
          .width('100%')
          .margin({ top: 14 })

          // 性别：单选胶囊
          Column() {
            Text('性别')
              .fontSize(13)
              .fontColor(Theme.inkSecondary(this.isDark))
              .width('100%')
            Row({ space: 10 }) {
              ForEach(GENDERS, (g: string) => {
                Text(g)
                  .fontSize(14)
                  .fontColor(this.gender === g ? Color.White : Theme.inkSecondary(this.isDark))
                  .backgroundColor(this.gender === g ? Theme.accent(this.isDark) : Theme.glass(this.isDark))
                  .borderRadius(12)
                  .textAlign(TextAlign.Center)
                  .height(40)
                  .layoutWeight(1)
                  .onClick(() => {
                    this.gender = g;
                  })
              }, (g: string) => g)
            }
            .width('100%')
            .margin({ top: 12 })
          }
          .backgroundColor(Theme.glass(this.isDark))
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: Theme.glassBorder(this.isDark) })
          .borderRadius(18)
          .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
          .padding(20)
          .width('100%')
          .margin({ top: 14 })

          // 生日：点击唤起系统日期选择弹窗
          Column() {
            Text('生日')
              .fontSize(13)
              .fontColor(Theme.inkSecondary(this.isDark))
              .width('100%')
            Row() {
              Text(this.birthday !== '' ? this.birthday : '请选择生日')
                .fontSize(15)
                .fontColor(this.birthday !== '' ? Theme.ink(this.isDark) : Theme.inkTertiary(this.isDark))
                .layoutWeight(1)
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(14)
                .fontColor([Theme.inkTertiary(this.isDark)])
            }
            .height(46)
            .width('100%')
            .margin({ top: 12 })
            .onClick(() => {
              this.showBirthdayPicker();
            })
          }
          .backgroundColor(Theme.glass(this.isDark))
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: Theme.glassBorder(this.isDark) })
          .borderRadius(18)
          .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
          .padding(20)
          .width('100%')
          .margin({ top: 14 })

          // 保存（液态玻璃主按钮）
          Button(this.saving ? '保存中…' : '保存')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .type(ButtonType.Capsule)
            .backgroundColor(Theme.accentGlassStrong(this.isDark))
            .backgroundBlurStyle(BlurStyle.Thin)
            .border({ width: 1, color: Theme.accentGlassBorder(this.isDark) })
            .fontColor(Theme.accent(this.isDark))
            .shadow({
              radius: 16,
              color: this.isDark ? 'rgba(123,147,255,0.35)' : 'rgba(61,90,241,0.30)',
              offsetX: 0,
              offsetY: 6
            })
            .height(52)
            .width('100%')
            .margin({ top: 24, bottom: 24 })
            .onClick(() => {
              this.save();
            })
        }
        .padding({ left: 24, right: 24 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
  }
}
