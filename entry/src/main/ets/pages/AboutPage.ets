import { promptAction } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { Store } from '../store/Store';
import { CloudSync } from '../common/CloudSync';
import { Theme } from '../common/Theme';

// ============================================================
// ⚠️【版本更新内容编辑区】
// 发布新版本时，请在下方 UPDATE_LOGS 数组的【最前面】插入一条新记录：
//   {
//     version: 'v1.1.0',        // 版本号
//     date: '2026-10-20',       // 发布日期
//     items: [                  // 更新内容，每条一行
//       '新增了 XXX 功能',
//       '修复了 XXX 问题'
//     ]
//   }
// 页面会自动按数组顺序展示更新日志，无需修改其他任何代码。
// ============================================================
interface UpdateLog {
  version: string;
  date: string;
  items: string[];
}

const UPDATE_LOGS: UpdateLog[] = [
  {
    version: 'v1.0.0',
    date: '2026-10-14',
    items: [
      '全新上线：欢迎页与登录注册流程',
      '今日目标与当前词库学习进度展示',
      '已掌握单词列表，支持搜索与三种排序',
      '学习日历：记录每天学过的单词',
      '每日目标支持预设与自定义设置'
    ]
  },
  {
    version: 'v1.0.5',
    date: '2026-10-15',
    items: [
      '欢迎页和登录页进行全新优化美观',
      '万词斩已更名为Yoji.（要记单词）',
      '优化了“我的”页面布局',
      '将词库选择从底部导航栏移至“我的”页面',
      '“掌握情况”里的“学习中”已可以正常交互',
      '新增“单词本”功能，现在用户可以自己收藏单词了'
    ]
  },
  {
    version: 'v1.1.0',
    date: '2026-10-16',
    items: [
      '全新上线：视频学习',
      '优化了“我的Yoji”页面布局',
      '优化了“学习日历”的界面布局',
      '新增深色模式：各页面右上角月亮按钮一键切换',
      '优化了底部导航栏的样式',
      '全新操作逻辑：学单词时左右滑即可进行标记'
    ]
  },
  {
    version: 'v1.2.0',
    date: '2026-10-20',
    items: [
      '新增“编辑资料”页面：头像、昵称、性别、生日一键修改',
      '全面优化视觉效果，更改为液态玻璃主题',
      '视频新增收藏功能，且用户可以在视频里自行添加单词到单词本',
      '接入云端账号登录与学习进度同步',
      '新增退出登录、换账号数据隔离与云端清空',
      '视频改为在线链接播放，安装包体积减小'
    ]
  }
];

// 关于与数据：版本更新信息 + 数据管理（清空学习记录）
@Entry
@Component
struct AboutPage {
  // 深色模式开关：双向绑定 AppStorage，切换后页面配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;
  private store: Store = Store.get();

  private async clearData(): Promise<void> {
    await this.store.clearAll();
    // 已登录时同步清空云端，避免下次登录又被合并回来
    if (this.store.isLoggedIn) {
      await CloudSync.resetRemote();
    }
    promptAction.showToast({ message: '学习记录已清空' });
  }

  private confirmClear(): void {
    promptAction.showDialog({
      title: '清空学习记录',
      message: '将删除所有单词进度与统计，且无法恢复。确定继续吗？',
      buttons: [
        { text: '取消', color: Theme.inkSecondary(this.isDark) },
        { text: '清空', color: Theme.danger(this.isDark) }
      ]
    }).then((res) => {
      if (res.index === 1) {
        this.clearData();
      }
    });
  }

  // 单条版本更新日志
  @Builder
  UpdateLogCard(log: UpdateLog) {
    Column() {
      Row() {
        Text(log.version)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink(this.isDark))
        Blank()
        Text(log.date)
          .fontSize(12)
          .fontColor(Theme.inkTertiary(this.isDark))
      }
      .width('100%')

      ForEach(log.items, (item: string) => {
        Row() {
          Circle({ width: 5, height: 5 })
            .fill(Theme.accent(this.isDark))
            .margin({ top: 5 })
          Text(item)
            .fontSize(13)
            .fontColor(Theme.inkSecondary(this.isDark))
            .lineHeight(20)
            .layoutWeight(1)
            .margin({ left: 8 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({ top: 8 })
      }, (item: string, idx: number) => `${log.version}-${idx}`)
    }
    .alignItems(HorizontalAlign.Start)
    // 与首页一致的玻璃质感：半透明底 + 背景模糊 + 高光描边 + 悬空阴影
    .backgroundColor(Theme.glass(this.isDark))
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Theme.glassBorder(this.isDark) })
    .borderRadius(18)
    .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
    .padding(20)
    .width('100%')
    .margin({ top: 12 })
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
        Text('关于与数据')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink(this.isDark))
          .margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })

      Scroll() {
        Column() {
          // 应用信息
          Column() {
            // ⚠️【自定义 LOGO】换图标方法：用你的 PNG 直接覆盖
            //   entry/src/main/resources/base/media/logo.png
            // 文件名保持 logo.png 即可，无需修改代码；建议使用正方形透明底 PNG（≥128x128）
            Image($r('app.media.appIcon'))
              .width(64)
              .height(64)
              .borderRadius(18)
              .objectFit(ImageFit.Cover)

            Text('Yoji.')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink(this.isDark))
              .margin({ top: 12 })
            Text('v1.2.0')
              .fontSize(13)
              .fontColor(Theme.inkSecondary(this.isDark))
              .margin({ top: 4 })
          }
          .backgroundColor(Theme.glass(this.isDark))
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: Theme.glassBorder(this.isDark) })
          .borderRadius(24)
          .shadow({ radius: 14, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
          .padding(24)
          .width('100%')
          .margin({ top: 12 })

          // 版本更新
          Text('版本更新')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink(this.isDark))
            .width('100%')
            .margin({ top: 24 })

          ForEach(UPDATE_LOGS, (log: UpdateLog) => {
            this.UpdateLogCard(log)
          }, (log: UpdateLog) => log.version)

          // 数据（页面最底部）
          Column() {
            Text('数据')
              .fontSize(15)
              .fontColor(Theme.ink(this.isDark))
              .width('100%')
            Text('清空学习记录')
              .fontSize(15)
              .fontColor(Theme.danger(this.isDark))
              .width('100%')
              .margin({ top: 16 })
              .onClick(() => {
                this.confirmClear();
              })
          }
          .backgroundColor(Theme.glass(this.isDark))
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: Theme.glassBorder(this.isDark) })
          .borderRadius(18)
          .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
          .padding(20)
          .width('100%')
          .margin({ top: 24, bottom: 24 })
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
