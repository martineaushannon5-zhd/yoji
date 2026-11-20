<!-- 500页面 -->
<template>
  <ArtException
    :data="{
      title: '500',
      desc: '服务暂时出了点问题，请稍后重试；持续出现的话，把当前时间和页面发给维护者。',
      btnText: '回到仪表盘',
      imgUrl
    }"
  />
</template>

<script setup lang="ts">
  import imgUrl from '@imgs/svg/500.svg'
  defineOptions({ name: 'Exception500' })
</script>