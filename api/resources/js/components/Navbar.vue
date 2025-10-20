<template>
    <nav class="bg-gradient-to-r from-purple-600 to-indigo-600 text-white shadow-lg">
        <div class="mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex items-center justify-between h-16">
                <div class="flex items-center">
                    <div class="flex-shrink-0 flex items-center gap-3">
                        <svg class="h-8 w-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                                  d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
                        </svg>
                        <span class="text-xl font-bold">ServerBond Agent</span>
                    </div>
                </div>
                
                <div class="flex items-center gap-4">
                    <div class="flex items-center gap-2 bg-white/10 px-3 py-1 rounded-full">
                        <div class="h-2 w-2 bg-green-400 rounded-full animate-pulse"></div>
                        <span class="text-sm font-medium">{{ systemStatus }}</span>
                    </div>
                    
                    <button @click="refreshData" class="p-2 hover:bg-white/10 rounded-lg transition">
                        <svg class="h-5 w-5" :class="{'animate-spin': isRefreshing}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                                  d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                        </svg>
                    </button>
                </div>
            </div>
        </div>
    </nav>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import axios from 'axios';

const systemStatus = ref('Active');
const isRefreshing = ref(false);

const checkHealth = async () => {
    try {
        const response = await axios.get('/health');
        systemStatus.value = response.data.status === 'healthy' ? 'Active' : 'Degraded';
    } catch (error) {
        systemStatus.value = 'Error';
    }
};

const refreshData = async () => {
    isRefreshing.value = true;
    await checkHealth();
    setTimeout(() => {
        isRefreshing.value = false;
    }, 500);
};

onMounted(() => {
    checkHealth();
    setInterval(checkHealth, 30000); // Her 30 saniyede bir kontrol
});
</script>

