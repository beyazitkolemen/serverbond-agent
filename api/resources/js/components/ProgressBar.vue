<template>
    <div class="w-full h-full flex items-end">
        <div class="w-full bg-gray-200 rounded-full h-4">
            <div
                class="h-4 rounded-full transition-all duration-500"
                :class="`bg-${color}-500`"
                :style="{ width: `${value}%` }"
            ></div>
        </div>
    </div>
</template>

<script setup>
defineProps({
    value: {
        type: Number,
        default: 0,
    },
    color: {
        type: String,
        default: 'blue',
    },
});
</script>

