<template>
    <div>
        <div class="flex items-center justify-between mb-8">
            <div>
                <h1 class="text-3xl font-bold text-gray-900">Sites</h1>
                <p class="text-gray-600 mt-2">Tüm sitelerinizi yönetin</p>
            </div>
            <router-link to="/sites/create" class="btn btn-primary">
                + Yeni Site Ekle
            </router-link>
        </div>

        <!-- Sites List -->
        <div v-if="loading" class="text-center py-12">
            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600 mx-auto"></div>
            <p class="mt-4 text-gray-600">Yükleniyor...</p>
        </div>

        <div v-else-if="sites.length === 0" class="card text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M5 19a2 2 0 01-2-2V7a2 2 0 012-2h4l2 2h4a2 2 0 012 2v1M5 19h14a2 2 0 002-2v-5a2 2 0 00-2-2H9a2 2 0 00-2 2v5a2 2 0 01-2 2z" />
            </svg>
            <h3 class="mt-2 text-lg font-medium text-gray-900">Henüz site yok</h3>
            <p class="mt-1 text-sm text-gray-500">İlk sitenizi oluşturarak başlayın</p>
            <div class="mt-6">
                <router-link to="/sites/create" class="btn btn-primary">
                    Yeni Site Oluştur
                </router-link>
            </div>
        </div>

        <div v-else class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div v-for="site in sites" :key="site.id"
                 class="card hover:shadow-xl transition-shadow cursor-pointer"
                 @click="$router.push(`/sites/${site.id}`)">
                <div class="flex items-start justify-between mb-4">
                    <div class="flex-1">
                        <h3 class="text-xl font-bold text-gray-900 mb-2">{{ site.domain }}</h3>
                        <div class="flex items-center gap-2">
                            <span class="px-3 py-1 rounded-full text-xs font-semibold"
                                  :class="getSiteTypeColor(site.site_type)">
                                {{ site.site_type }}
                            </span>
                            <span v-if="site.php_version" class="px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-xs font-semibold">
                                PHP {{ site.php_version }}
                            </span>
                            <span v-if="site.ssl_enabled" class="px-3 py-1 bg-green-100 text-green-700 rounded-full text-xs font-semibold">
                                🔒 SSL
                            </span>
                        </div>
                    </div>
                    <div class="flex gap-2">
                        <button @click.stop="deploySite(site.id)"
                                class="p-2 hover:bg-purple-50 rounded-lg transition">
                            <svg class="h-5 w-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                      d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                            </svg>
                        </button>
                        <button @click.stop="deleteSite(site.id)"
                                class="p-2 hover:bg-red-50 rounded-lg transition">
                            <svg class="h-5 w-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                      d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                            </svg>
                        </button>
                    </div>
                </div>

                <div class="text-sm text-gray-600 space-y-1">
                    <div v-if="site.git_repo" class="flex items-center gap-2">
                        <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M12.316 3.051a1 1 0 01.633 1.265l-4 12a1 1 0 11-1.898-.632l4-12a1 1 0 011.265-.633zM5.707 6.293a1 1 0 010 1.414L3.414 10l2.293 2.293a1 1 0 11-1.414 1.414l-3-3a1 1 0 010-1.414l3-3a1 1 0 011.414 0zm8.586 0a1 1 0 011.414 0l3 3a1 1 0 010 1.414l-3 3a1 1 0 11-1.414-1.414L16.586 10l-2.293-2.293a1 1 0 010-1.414z" clip-rule="evenodd" />
                        </svg>
                        <span class="truncate">{{ site.git_branch || 'main' }}</span>
                    </div>
                    <div class="flex items-center gap-2 text-xs text-gray-500">
                        <span>Oluşturulma: {{ formatDate(site.created_at) }}</span>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import axios from 'axios';

const sites = ref([]);
const loading = ref(true);

const loadSites = async () => {
    try {
        const response = await axios.get('/api/sites');
        sites.value = response.data;
    } catch (error) {
        console.error('Site yükleme hatası:', error);
    } finally {
        loading.value = false;
    }
};

const getSiteTypeColor = (type) => {
    const colors = {
        laravel: 'bg-red-100 text-red-700',
        php: 'bg-purple-100 text-purple-700',
        static: 'bg-blue-100 text-blue-700',
        python: 'bg-yellow-100 text-yellow-700',
        nodejs: 'bg-green-100 text-green-700',
    };
    return colors[type] || 'bg-gray-100 text-gray-700';
};

const formatDate = (date) => {
    return new Date(date).toLocaleDateString('tr-TR');
};

const deploySite = async (siteId) => {
    if (!confirm('Bu siteyi deploy etmek istediğinize emin misiniz?')) return;

    try {
        await axios.post('/api/deploy', {
            site_id: siteId,
            run_migrations: true,
            clear_cache: true,
        });
        alert('Deploy başlatıldı!');
    } catch (error) {
        alert('Deploy başlatılamadı: ' + error.message);
    }
};

const deleteSite = async (siteId) => {
    if (!confirm('Bu siteyi silmek istediğinize emin misiniz?')) return;

    try {
        await axios.delete(`/api/sites/${siteId}`);
        await loadSites();
        alert('Site silindi!');
    } catch (error) {
        alert('Site silinemedi: ' + error.message);
    }
};

onMounted(() => {
    loadSites();
});
</script>

