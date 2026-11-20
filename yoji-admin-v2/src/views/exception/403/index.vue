<!-- 403页面 -->
<template>
  <ArtException
    :data="{
      title: '403',
      desc: '你没有访问这个页面的权限。如果确定需要，请联系管理员开通。',
      btnText: '回到仪表盘',
      imgUrl
    }"
  />
</template>

<script setup lang="ts">
  import imgUrl from '@imgs/svg/403.svg'
  defineOptions({ name: 'Exception403' })
</script>