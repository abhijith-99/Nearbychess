'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "001b3792e1e25bf4825d299cb351ed2b",
"assets/AssetManifest.bin.json": "52572ca82be844dd0e0806e35af35462",
"assets/AssetManifest.json": "00143c21b1ad4b338aaa03b06526ae78",
"assets/assets/android_light_rd_SI.svg": "0f9969e334b84b9ae36f4b9860e8e809",
"assets/assets/Animation.gif": "1aed5ef7a3cc265e3c6d9c05b70ed99d",
"assets/assets/avatars/avatar-default.png": "6fe5573322d128579373d07444d1405f",
"assets/assets/avatars/avatar1.png": "d0778a1e0340be47595fa5f0a268f58c",
"assets/assets/avatars/avatar2.png": "24dda530233993f4c0741d39129ee1a4",
"assets/assets/avatars/avatar3.png": "fa3c7ce456995ee7664b1dc60dfcb631",
"assets/assets/avatars/avatar4.png": "b593860be3a63aee991c90aa570ab08d",
"assets/assets/avatars/avatar5.png": "f4281dbf629bf792c974dcfb6ccc1ebe",
"assets/assets/avatars/avatar6.png": "e6774a8919c2e3ab3f9cb3d6725c1852",
"assets/assets/background_knight.jpg": "563f15f2b2cac412865362f66f3a7c17",
"assets/assets/battle.png": "4b639539a7846ce71f3aa3ea89889f5e",
"assets/assets/challenge.webp": "e1fb911c2c29532ec376e9bf12c7376f",
"assets/assets/chess_king.png": "daaad903dbf8282501d08844e607dc21",
"assets/assets/chess_logo.svg": "9075c57678c3380f7af8ac979e73ff02",
"assets/assets/chess_pieces/black/bishop.png": "95e1b0cb19facdf4615ca6e08ba0bd6c",
"assets/assets/chess_pieces/black/king.png": "86c3967a19a686f35594913b12165907",
"assets/assets/chess_pieces/black/knight.png": "39c365c1027b667e7cb2b2577dc9602f",
"assets/assets/chess_pieces/black/pawn.png": "6a0d3c587d704c268f7adde8aaa6dce3",
"assets/assets/chess_pieces/black/queen.png": "a534752061705d4f0bb61e15f722e565",
"assets/assets/chess_pieces/black/rook.png": "47ec7d3542bab547d77363b25fb15da3",
"assets/assets/chess_pieces/white/bishop.png": "35d1427a3fe5134008934504860d424e",
"assets/assets/chess_pieces/white/king.png": "92271801a5bd8ac6334c5755f52c0753",
"assets/assets/chess_pieces/white/knight.png": "e050cecdc9de5c3c2886bb2117165bda",
"assets/assets/chess_pieces/white/pawn.png": "166ea8dfda70af4d0b815a28eb180382",
"assets/assets/chess_pieces/white/queen.png": "6bbf7affe7b78bf09ea072a627fa5a13",
"assets/assets/chess_pieces/white/rook.png": "a9a56e1bf38c10dd2def49b7186a9e3c",
"assets/assets/fonts/Poppins-Bold.ttf": "08c20a487911694291bd8c5de41315ad",
"assets/assets/fonts/Poppins-Regular.ttf": "093ee89be9ede30383f39a899c485a82",
"assets/assets/fonts/Roboto-Medium.ttf": "68ea4734cf86bd544650aee05137d7bb",
"assets/assets/google_logo.svg": "14b4fba703b5e06925fd92a56a770a40",
"assets/assets/location-pin-solid.png": "13c18dd338a2302771e0665446962b42",
"assets/assets/location-pin-solid.webp": "4962fab5440a90b78a971878957dd8d6",
"assets/assets/location_icon.png": "d0707406309e0db8d1b585ec0fcbfe0e",
"assets/assets/logo1.png": "bd4c0e1dc30cea7528082f43f6f0109e",
"assets/assets/mono-white.jpg": "8d54e517e2de5762b09031db70adfa10",
"assets/assets/monochrome-board.jpg": "3cece18ad45e118c345c7e09c524e169",
"assets/assets/NBC-token.png": "302ed0b6d942d29a7ed249b2ca316eb2",
"assets/assets/new_map.json": "7e7c920aed5b81b5318d221fa65a3a0d",
"assets/assets/paper-plane-solid.svg": "c98fb6b69b4d5797db636ce623fd4643",
"assets/assets/phone_logo.svg": "abe235759cd3c8079ba36bfd98554361",
"assets/assets/timer.svg": "a4e359f47ad993974dba503bf0c420ac",
"assets/FontManifest.json": "6ef073cfead874f13119ba816cbcad36",
"assets/fonts/MaterialIcons-Regular.otf": "442dcc0d7abebefce7a7243e20b8c479",
"assets/NOTICES": "a8be0e399c524008763bb42cf2f0dc40",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "b54cd959f637ea41a17e397cdd8ab170",
"assets/shaders/ink_sparkle.frag": "4096b5150bac93c41cbc9b45276bd90f",
"canvaskit/canvaskit.js": "eb8797020acdbdf96a12fb0405582c1b",
"canvaskit/canvaskit.wasm": "73584c1a3367e3eaf757647a8f5c5989",
"canvaskit/chromium/canvaskit.js": "0ae8bbcc58155679458a0f7a00f66873",
"canvaskit/chromium/canvaskit.wasm": "143af6ff368f9cd21c863bfa4274c406",
"canvaskit/skwasm.js": "87063acf45c5e1ab9565dcf06b0c18b8",
"canvaskit/skwasm.wasm": "2fc47c0a0c3c7af8542b601634fe9674",
"canvaskit/skwasm.worker.js": "bfb704a6c714a75da9ef320991e88b03",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "59a12ab9d00ae8f8096fffc417b6e84f",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "da3e287ffe2766d8ff0b71c88f5fe1b3",
"/": "da3e287ffe2766d8ff0b71c88f5fe1b3",
"main.dart.js": "05f8b1aa9d0f4f9b034eaeff1e6c518c",
"manifest.json": "d464f8159f5fba279c56408225a48a46",
"version.json": "48074eed3f1d437672769af726e544d4"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"assets/AssetManifest.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
