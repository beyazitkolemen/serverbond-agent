<template>
    <div id="app" class="min-h-screen bg-gray-50">
        <Navbar />
        <div class="flex">
            <Sidebar />
            <main class="flex-1 p-6">
                <router-view />
            </main>
        </div>
    </div>
</template>

<script setup>
import Navbar from './components/Navbar.vue';
import Sidebar from './components/Sidebar.vue';
</script>

