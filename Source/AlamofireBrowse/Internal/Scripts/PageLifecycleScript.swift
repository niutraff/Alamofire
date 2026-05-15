#if os(iOS)

import Foundation

enum PageLifecycleScript {
    static let messageHandlerName = "browseLifecycle"

    static let source = """
    (function(){
      if (window.__browseLifecycleInstalled) return;
      window.__browseLifecycleInstalled = true;

      var t0 = Date.now();
      function send(event) {
        try {
          window.webkit.messageHandlers.browseLifecycle.postMessage({
            event: event,
            elapsed: Date.now() - t0,
            readyState: document.readyState,
            url: location.href
          });
        } catch (e) {}
      }

      send('script-injected');

      document.addEventListener('readystatechange', function(){
        send('readystate-' + document.readyState);
      });

      if (document.readyState === 'interactive' || document.readyState === 'complete') {
        send('readystate-' + document.readyState);
      }

      document.addEventListener('DOMContentLoaded', function(){ send('DOMContentLoaded'); });
      window.addEventListener('load', function(){ send('window-load'); });

      function markAppReady() {
        send('app-ready');
      }
      window.addEventListener('checkInnAppReady', markAppReady, { once: true });
      window.addEventListener('browseAppReady', markAppReady, { once: true });
      if (window.__browseAppReady === true) {
        markAppReady();
      }

      // First real interaction handler attached: prove page is interactive
      var firstInteractive = false;
      function markInteractive() {
        if (firstInteractive) return;
        firstInteractive = true;
        send('first-pointer-handler-runs');
      }
      window.addEventListener('pointerdown', markInteractive, { capture: true, once: true });
      window.addEventListener('touchstart', markInteractive, { capture: true, once: true, passive: true });
      window.addEventListener('click', markInteractive, { capture: true, once: true });

      function reportRedirect(kind, target) {
        try {
          window.webkit.messageHandlers.browseLifecycle.postMessage({
            event: 'jsRedirect-' + kind,
            elapsed: Date.now() - t0,
            readyState: document.readyState,
            url: location.href,
            target: String(target)
          });
        } catch (e) {}
      }

      try {
        var origReplace = window.location.replace.bind(window.location);
        window.location.replace = function(u) { reportRedirect('replace', u); return origReplace(u); };
      } catch (e) {}
      try {
        var origAssign = window.location.assign.bind(window.location);
        window.location.assign = function(u) { reportRedirect('assign', u); return origAssign(u); };
      } catch (e) {}
      try {
        var hrefDesc = Object.getOwnPropertyDescriptor(Window.prototype, 'location') ||
                       Object.getOwnPropertyDescriptor(window, 'location');
        // can't reliably wrap location setter in WKWebView; rely on assign/replace + readystate
      } catch (e) {}
      try {
        var origPushState = history.pushState;
        history.pushState = function(s, t, u) { if (u) reportRedirect('pushState', u); return origPushState.apply(history, arguments); };
        var origReplaceState = history.replaceState;
        history.replaceState = function(s, t, u) { if (u) reportRedirect('replaceState', u); return origReplaceState.apply(history, arguments); };
      } catch (e) {}

      function checkMetaRefresh() {
        var m = document.querySelector('meta[http-equiv="refresh" i]');
        if (m) reportRedirect('metaRefresh', m.getAttribute('content') || '');
      }
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', checkMetaRefresh, { once: true });
      } else {
        checkMetaRefresh();
      }
    })();
    """
}

#endif
