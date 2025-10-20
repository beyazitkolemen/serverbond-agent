<template>
    <div>
        <div class="mb-8">
            <h1 class="text-3xl font-bold text-gray-900">Dashboard</h1>
            <p class="text-gray-600 mt-2">ServerBond Agent - Server Management Platform</p>
        </div>

        <!-- Stats Cards -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            <StatsCard
                title="Total Sites"
                :value="stats.totalSites"
                icon="server"
                color="purple"
            />
            <StatsCard
                title="Active Deploys"
                :value="stats.activeDeploys"
                icon="rocket"
                color="blue"
            />
            <StatsCard
                title="Databases"
                :value="stats.databases"
                icon="database"
                color="green"
            />
            <StatsCard
                title="PHP Versions"
                :value="stats.phpVersions"
                icon="code"
                color="orange"
            />
        </div>

        <!-- System Stats -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
            <div class="bg-white rounded-xl shadow-md p-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-4">CPU Usage</h3>
                <div class="flex items-end justify-between">
                    <div class="text-4xl font-bold text-purple-600">{{ systemStats.cpu }}%</div>
                    <div class="h-24 flex-1 ml-4">
                        <ProgressBar :value="systemStats.cpu" color="purple" />
                    </div>
                </div>
            </div>

            <div class="bg-white rounded-xl shadow-md p-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-4">Memory Usage</h3>
                <div class="flex items-end justify-between">
                    <div class="text-4xl font-bold text-blue-600">{{ systemStats.memory }}%</div>
                    <div class="h-24 flex-1 ml-4">
                        <ProgressBar :value="systemStats.memory" color="blue" />
                    </div>
                </div>
            </div>

            <div class="bg-white rounded-xl shadow-md p-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-4">Disk Usage</h3>
                <div class="flex items-end justify-between">
                    <div class="text-4xl font-bold text-green-600">{{ systemStats.disk }}%</div>
                    <div class="h-24 flex-1 ml-4">
                        <ProgressBar :value="systemStats.disk" color="green" />
                    </div>
                </div>
            </div>
        </div>

        <!-- Recent Deploys -->
        <div class="bg-white rounded-xl shadow-md p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Recent Deployments</h3>
            <div v-if="recentDeploys.length === 0" class="text-center py-12 text-gray-500">
                Henüz deploy yok
            </div>
            <div v-else class="space-y-3">
                <div v-for="deploy in recentDeploys" :key="deploy.id"
                     class="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition">
                    <div class="flex items-center gap-4">
                        <div class="h-10 w-10 rounded-full flex items-center justify-center"
                             :class="getDeployStatusColor(deploy.status)">
                            <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                            </svg>
                        </div>
                        <div>
                            <div class="font-semibold text-gray-900">{{ deploy.site_name }}</div>
                            <div class="text-sm text-gray-500">{{ deploy.branch }} - {{ deploy.commit }}</div>
                        </div>
                    </div>
                    <div class="text-right">
                        <div class="text-sm font-medium capitalize" :class="getDeployTextColor(deploy.status)">
                            {{ deploy.status }}
                        </div>
                        <div class="text-xs text-gray-500">{{ deploy.time }}</div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import axios from 'axios';
import StatsCard from '../components/StatsCard.vue';
import ProgressBar from '../components/ProgressBar.vue';

const stats = ref({
    totalSites: 0,
    activeDeploys: 0,
    databases: 0,
    phpVersions: 3,
});

const systemStats = ref({
    cpu: 0,
    memory: 0,
    disk: 0,
});

const recentDeploys = ref([]);

const loadDashboard = async () => {
    try {
        // System stats
        const statsResponse = await axios.get('/api/system/stats');
        systemStats.value = {
            cpu: statsResponse.data.cpu?.percent || 0,
            memory: statsResponse.data.memory?.percent || 0,
            disk: statsResponse.data.disk?.percent || 0,
        };

        // Sites count
        const sitesResponse = await axios.get('/api/sites');
        stats.value.totalSites = sitesResponse.data.length || 0;

        // Databases count
        const dbResponse = await axios.get('/api/database');
        stats.value.databases = dbResponse.data.length || 0;

    } catch (error) {
        console.error('Dashboard yükleme hatası:', error);
    }
};

const getDeployStatusColor = (status) => {
    const colors = {
        success: 'bg-green-100 text-green-600',
        failed: 'bg-red-100 text-red-600',
        in_progress: 'bg-blue-100 text-blue-600',
        pending: 'bg-yellow-100 text-yellow-600',
    };
    return colors[status] || 'bg-gray-100 text-gray-600';
};

const getDeployTextColor = (status) => {
    const colors = {
        success: 'text-green-600',
        failed: 'text-red-600',
        in_progress: 'text-blue-600',
        pending: 'text-yellow-600',
    };
    return colors[status] || 'text-gray-600';
};

onMounted(() => {
    loadDashboard();
    setInterval(loadDashboard, 60000); // Her dakika güncelle
});
</script>

