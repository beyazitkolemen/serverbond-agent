import { createRouter, createWebHistory } from 'vue-router';

const routes = [
    {
        path: '/',
        name: 'dashboard',
        component: () => import('../pages/Dashboard.vue'),
        meta: { title: 'Dashboard' }
    },
    {
        path: '/sites',
        name: 'sites',
        component: () => import('../pages/Sites.vue'),
        meta: { title: 'Sites' }
    },
    {
        path: '/sites/create',
        name: 'sites.create',
        component: () => import('../pages/SiteCreate.vue'),
        meta: { title: 'Create Site' }
    },
    {
        path: '/sites/:id',
        name: 'sites.show',
        component: () => import('../pages/SiteDetails.vue'),
        meta: { title: 'Site Details' }
    },
    {
        path: '/deploys',
        name: 'deploys',
        component: () => import('../pages/Deploys.vue'),
        meta: { title: 'Deployments' }
    },
    {
        path: '/databases',
        name: 'databases',
        component: () => import('../pages/Databases.vue'),
        meta: { title: 'Databases' }
    },
    {
        path: '/php',
        name: 'php',
        component: () => import('../pages/PhpVersions.vue'),
        meta: { title: 'PHP Versions' }
    },
    {
        path: '/system',
        name: 'system',
        component: () => import('../pages/System.vue'),
        meta: { title: 'System' }
    },
];

const router = createRouter({
    history: createWebHistory(),
    routes,
});

router.beforeEach((to, from, next) => {
    document.title = to.meta.title ? `${to.meta.title} - ServerBond Agent` : 'ServerBond Agent';
    next();
});

export default router;

