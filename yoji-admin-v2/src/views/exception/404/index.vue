<!-- 404页面 -->
<template>
  <ArtException
    :data="{
      title: '404',
      desc: '页面不存在，或已经被移动到别处。检查一下地址，或者回到仪表盘继续。',
      btnText: '回到仪表盘',
      imgUrl
    }"
  />
</template>

<script setup lang="ts">
  import imgUrl from '@imgs/svg/404.svg'
  defineOptions({ name: 'Exception404' })
</script>