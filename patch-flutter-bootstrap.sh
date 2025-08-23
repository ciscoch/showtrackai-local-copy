#!/bin/bash

# This script patches flutter_bootstrap.js to force HTML renderer and disable CanvasKit

echo "🔧 Patching Flutter bootstrap for HTML renderer..."

if [ -f "build/web/flutter_bootstrap.js" ]; then
  # Create a backup
  cp build/web/flutter_bootstrap.js build/web/flutter_bootstrap.js.original
  
  # Read the file
  CONTENT=$(cat build/web/flutter_bootstrap.js)
  
  # Replace the build config to use HTML renderer
  cat > build/web/flutter_bootstrap.js << 'EOF'
// Patched Flutter bootstrap - Forces HTML renderer
(function() {
  // Original Flutter loader code
  var C={blink:!0,gecko:!1,webkit:!1,unknown:!1},R=()=>navigator.vendor==="Google Inc."||navigator.userAgent.includes("Edg/")?"blink":navigator.vendor==="Apple Computer, Inc."?"webkit":navigator.vendor===""&&navigator.userAgent.includes("Firefox")?"gecko":"unknown",L=R(),x=()=>typeof ImageDecoder>"u"?!1:L==="blink",K=()=>typeof Intl.v8BreakIterator<"u"&&typeof Intl.Segmenter<"u",B=()=>{let i=[0,97,115,109,1,0,0,0,1,5,1,95,1,120,0];return WebAssembly.validate(new Uint8Array(i))},w={browserEngine:L,hasImageCodecs:x(),hasChromiumBreakIterators:K(),supportsWasmGC:B(),crossOriginIsolated:window.crossOriginIsolated};
  
  function c(...i){return new URL(T(...i),document.baseURI).toString()}
  function T(...i){return i.filter(e=>!!e).map((e,r)=>r===0?I(e):z(I(e))).filter(e=>e.length).join("/")}
  function z(i){let e=0;for(;e<i.length&&i.charAt(e)==="/";)e++;return i.substring(e)}
  function I(i){let e=i.length;for(;e>0&&i.charAt(e-1)==="/";)e--;return i.substring(0,e)}
  
  var v=class{
    constructor(){this._scriptLoaded=!1}
    setTrustedTypesPolicy(e){this._ttPolicy=e}
    async loadEntrypoint(e){
      let{entrypointUrl:r=c("main.dart.js"),onEntrypointLoaded:t,nonce:n}=e||{};
      return this._loadJSEntrypoint(r,t,n)
    }
    async load(e,r,t,n,s){
      s??=u=>{u.initializeEngine(t).then(m=>m.runApp())};
      let{entrypointBaseUrl:a}=t,{entryPointBaseUrl:o}=t;
      if(!a&&o&&(console.warn("[deprecated] `entryPointBaseUrl` is deprecated and will be removed in a future release. Use `entrypointBaseUrl` instead."),a=o),e.compileTarget==="dart2wasm")return this._loadWasmEntrypoint(e,r,a,s);
      else{
        let u=e.mainJsPath??"main.dart.js",m=c(a,u);
        return this._loadJSEntrypoint(m,s,n)
      }
    }
    didCreateEngineInitializer(e){
      typeof this._didCreateEngineInitializerResolve=="function"&&(this._didCreateEngineInitializerResolve(e),this._didCreateEngineInitializerResolve=null,delete _flutter.loader.didCreateEngineInitializer),typeof this._onEntrypointLoaded=="function"&&this._onEntrypointLoaded(e)
    }
    _loadJSEntrypoint(e,r,t){
      let n=typeof r=="function";
      if(!this._scriptLoaded){
        this._scriptLoaded=!0;
        let s=this._createScriptTag(e,t);
        if(n)console.debug("Injecting <script> tag. Using callback."),this._onEntrypointLoaded=r,document.head.append(s);
        else return new Promise((a,o)=>{console.debug("Injecting <script> tag. Using Promises. Use the callback approach instead!"),this._didCreateEngineInitializerResolve=a,s.addEventListener("error",o),document.head.append(s)})
      }
    }
    _createScriptTag(e,r){
      let t=document.createElement("script");
      t.type="application/javascript",r&&(t.nonce=r);
      let n=e;
      return this._ttPolicy!=null&&(n=this._ttPolicy.createScriptURL(e)),t.src=n,t
    }
  };
  
  var b=class{
    async loadEntrypoint(e){
      let{serviceWorker:r,...t}=e||{};
      // Skip service worker completely
      console.log("Service worker disabled for HTML renderer");
      let a=new v;
      return this.didCreateEngineInitializer=a.didCreateEngineInitializer.bind(a),a.loadEntrypoint(t)
    }
    async load({serviceWorkerSettings:e,onEntrypointLoaded:r,nonce:t,config:n}={}){
      n??={};
      // Force HTML renderer
      n.renderer="html";
      let s=_flutter.buildConfig;
      if(!s)throw"FlutterLoader.load requires _flutter.buildConfig to be set";
      
      // Find HTML renderer build
      let p=s.builds.find(d=>!d.renderer||d.renderer==="html");
      if(!p){
        // Use the first available build
        p=s.builds[0]||{};
      }
      
      // Skip service worker
      console.log("Loading with HTML renderer, service worker disabled");
      
      let f=new v;
      this.didCreateEngineInitializer=f.didCreateEngineInitializer.bind(f);
      
      // Load without any special renderer setup
      return f.load(p,{},n,t,r)
    }
  };
  
  window._flutter||(window._flutter={});
  window._flutter.loader||(window._flutter.loader=new b);
})();

// Configure for HTML renderer only
if (!window._flutter) {
  window._flutter = {};
}

// Build config - HTML renderer only
_flutter.buildConfig = {
  "engineRevision": "1e9a811bf8e70466596bcf0ea3a8b5adb5f17f7f",
  "builds": [
    {
      "compileTarget": "dart2js",
      "renderer": "html",
      "mainJsPath": "main.dart.js"
    }
  ]
};

// Load without service worker
_flutter.loader.load({
  config: {
    renderer: "html"
  }
});
EOF

  echo "✅ Flutter bootstrap patched for HTML renderer"
else
  echo "❌ flutter_bootstrap.js not found!"
  exit 1
fi