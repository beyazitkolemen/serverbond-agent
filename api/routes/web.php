<?php

use Illuminate\Support\Facades\Route;

// Vue.js SPA - Tüm route'ları Vue Router'a yönlendir
Route::get('/{any}', function () {
    return view('app');
})->where('any', '.*');
