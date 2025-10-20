<template>
    <div class="bg-white rounded-xl shadow-md p-6 hover:shadow-lg transition-shadow">
        <div class="flex items-center justify-between">
            <div>
                <p class="text-sm font-medium text-gray-600 uppercase tracking-wide">{{ title }}</p>
                <p class="mt-2 text-3xl font-bold" :class="`text-${color}-600`">{{ value }}</p>
            </div>
            <div class="p-3 rounded-full" :class="`bg-${color}-100`">
                <component :is="iconComponent" :class="`h-8 w-8 text-${color}-600`" />
            </div>
        </div>
    </div>
</template>

<script setup>
import { computed } from 'vue';
import {
    ServerIcon,
    RocketLaunchIcon,
    CircleStackIcon,
    CodeBracketIcon,
} from '@heroicons/vue/24/outline';

const props = defineProps({
    title: String,
    value: [Number, String],
    icon: String,
    color: String,
});

const iconComponent = computed(() => {
    const icons = {
        server: ServerIcon,
        rocket: RocketLaunchIcon,
        database: CircleStackIcon,
        code: CodeBracketIcon,
    };
    return icons[props.icon] || ServerIcon;
});
</script>

