<template>
    <aside class="w-64 bg-white shadow-lg min-h-screen">
        <nav class="mt-6 px-4">
            <router-link 
                v-for="item in menuItems" 
                :key="item.name"
                :to="item.path"
                class="flex items-center gap-3 px-4 py-3 mb-2 rounded-lg transition-all"
                :class="isActive(item.path) ? 'bg-purple-100 text-purple-700 font-semibold' : 'text-gray-700 hover:bg-gray-100'"
            >
                <component :is="item.icon" class="h-5 w-5" />
                <span>{{ item.label }}</span>
                <span v-if="item.badge" class="ml-auto bg-purple-600 text-white text-xs px-2 py-1 rounded-full">
                    {{ item.badge }}
                </span>
            </router-link>
        </nav>
    </aside>
</template>

<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import {
    HomeIcon,
    ServerIcon,
    RocketLaunchIcon,
    CircleStackIcon,
    CodeBracketIcon,
    CpuChipIcon,
} from '@heroicons/vue/24/outline';

const route = useRoute();

const menuItems = [
    { name: 'dashboard', label: 'Dashboard', path: '/', icon: HomeIcon },
    { name: 'sites', label: 'Sites', path: '/sites', icon: ServerIcon },
    { name: 'deploys', label: 'Deployments', path: '/deploys', icon: RocketLaunchIcon },
    { name: 'databases', label: 'Databases', path: '/databases', icon: CircleStackIcon },
    { name: 'php', label: 'PHP Versions', path: '/php', icon: CodeBracketIcon },
    { name: 'system', label: 'System', path: '/system', icon: CpuChipIcon },
];

const isActive = (path) => {
    return route.path === path || (path !== '/' && route.path.startsWith(path));
};
</script>

