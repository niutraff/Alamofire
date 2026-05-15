#if os(iOS)

import Foundation

enum CredentialAutofillScript {
    static let messageHandlerName = "credentialAutofill"

    static let source = """
    (function() {
        if (window.__credentialAutofillInstalled) { return; }
        window.__credentialAutofillInstalled = true;

        var EMAIL_HINT = /e[-_]?mail|mail|login|user(name)?|account/i;
        var lastReport = { passwords: 0, emails: 0, total: 0, changed: 0, details: [] };
        var pendingMutationReport = false;

        function frameName() {
            try {
                return window.top === window ? 'main' : 'iframe';
            } catch (e) {
                return 'unknown';
            }
        }

        function post(event, extra) {
            try {
                var payload = {
                    event: event,
                    url: location.href,
                    readyState: document.readyState,
                    frame: frameName(),
                    passwords: lastReport.passwords || 0,
                    emails: lastReport.emails || 0,
                    total: lastReport.total || 0,
                    changed: lastReport.changed || 0,
                    details: lastReport.details || [],
                    timestamp: new Date().toISOString()
                };
                if (extra) {
                    for (var key in extra) {
                        if (Object.prototype.hasOwnProperty.call(extra, key)) {
                            payload[key] = extra[key];
                        }
                    }
                }
                window.webkit.messageHandlers.credentialAutofill.postMessage(payload);
            } catch (e) {}
        }

        function setIfMissing(el, value) {
            try {
                if (!el.getAttribute('autocomplete')) {
                    el.setAttribute('autocomplete', value);
                    return true;
                }
            } catch (e) {}
            return false;
        }

        function isTextLike(input) {
            if (!input || input.tagName !== 'INPUT') { return false; }
            var type = (input.type || 'text').toLowerCase();
            return type === 'text' || type === 'email' || type === 'search' ||
                   type === 'tel' || type === 'url';
        }

        function applyUsernameKeyboardHints(el) {
            try {
                if (!el.getAttribute('inputmode')) {
                    el.setAttribute('inputmode', 'email');
                }
                if (!el.getAttribute('autocapitalize')) {
                    el.setAttribute('autocapitalize', 'none');
                }
                el.setAttribute('spellcheck', 'false');
            } catch (e) {}
        }

        function classify(input) {
            if (!input || input.tagName !== 'INPUT') { return; }
            var type = (input.type || '').toLowerCase();
            if (type === 'hidden' || type === 'submit' || type === 'button' ||
                type === 'checkbox' || type === 'radio' || type === 'file') { return; }

            if (type === 'password') { return 'password'; }
            if (type === 'email') { return 'email'; }

            var autocomplete = (input.getAttribute('autocomplete') || '').toLowerCase();
            if (autocomplete === 'username') { return 'username'; }
            if (autocomplete === 'email') { return 'email'; }

            var name = (input.name || '') + ' ' + (input.id || '') + ' ' +
                       (input.placeholder || '') + ' ' +
                       (input.getAttribute('aria-label') || '');
            if (EMAIL_HINT.test(name)) { return 'email-like'; }
            return null;
        }

        function safeURL(value) {
            try {
                if (!value) { return ''; }
                var url = new URL(value, location.href);
                url.search = '';
                url.hash = '';
                return url.href;
            } catch (e) {
                return value || '';
            }
        }

        function describe(el) {
            return {
                tag: el.tagName,
                type: el.type || '',
                name: el.name || '',
                id: el.id || '',
                placeholder: el.placeholder || '',
                autocomplete: el.getAttribute('autocomplete') || '(none)',
                inForm: !!el.form,
                formAction: el.form ? safeURL(el.form.getAttribute('action') || location.href) : '',
                formMethod: el.form ? (el.form.getAttribute('method') || 'get') : ''
            };
        }

        function annotateAll(reason) {
            try {
                var inputs = document.querySelectorAll('input');
                var passwordInputs = [];
                var emailInputs = [];
                var details = [];

                for (var i = 0; i < inputs.length; i++) {
                    var kind = classify(inputs[i]);
                    var d = describe(inputs[i]);
                    d.classifiedAs = kind;
                    details.push(d);
                    if (kind === 'password') { passwordInputs.push(inputs[i]); }
                    else if (kind === 'email' || kind === 'email-like' || kind === 'username') { emailInputs.push(inputs[i]); }
                }

                var hasPassword = passwordInputs.length > 0;
                var changed = 0;
                var usernameByForm = [];

                if (passwordInputs.length === 1) {
                    if (setIfMissing(passwordInputs[0], 'current-password')) { changed++; }
                } else if (passwordInputs.length >= 2) {
                    if (setIfMissing(passwordInputs[0], 'new-password')) { changed++; }
                    for (var p = 1; p < passwordInputs.length; p++) {
                        if (setIfMissing(passwordInputs[p], 'new-password')) { changed++; }
                    }
                }

                for (var e = 0; e < emailInputs.length; e++) {
                    var el = emailInputs[e];
                    var inSameForm = hasPassword && el.form && passwordInputs[0].form === el.form;
                    var hint = (el.type || '').toLowerCase() === 'email'
                        ? 'email'
                        : (inSameForm || hasPassword ? 'username' : 'email');
                    if (setIfMissing(el, hint)) { changed++; }
                }

                for (var f = 0; f < passwordInputs.length; f++) {
                    var password = passwordInputs[f];
                    if (!password.form) { continue; }

                    var formInputs = password.form.querySelectorAll('input');
                    for (var u = 0; u < formInputs.length; u++) {
                        var candidate = formInputs[u];
                        if (candidate === password || !isTextLike(candidate)) { continue; }
                        if (usernameByForm.indexOf(candidate) >= 0) { continue; }

                        usernameByForm.push(candidate);
                        applyUsernameKeyboardHints(candidate);
                        if (setIfMissing(candidate, 'username')) { changed++; }
                        break;
                    }
                }

                details = [];
                var finalEmailCount = 0;
                for (var dIndex = 0; dIndex < inputs.length; dIndex++) {
                    var finalKind = classify(inputs[dIndex]);
                    var finalDetail = describe(inputs[dIndex]);
                    finalDetail.classifiedAs = finalKind;
                    details.push(finalDetail);
                    if (finalKind === 'email' || finalKind === 'email-like' || finalKind === 'username') {
                        finalEmailCount++;
                    }
                }

                lastReport = {
                    passwords: passwordInputs.length,
                    emails: finalEmailCount,
                    total: inputs.length,
                    changed: changed,
                    details: details,
                    timestamp: new Date().toISOString()
                };

                if (inputs.length > 0) {
                    console.log('[autofill]', JSON.stringify(lastReport));
                }
                post(reason || 'annotated');
            } catch (e) {
                console.warn('[autofill] error', e && e.message);
                post('error', { error: e && e.message ? e.message : String(e) });
            }
        }

        // Expose helper for Safari Web Inspector debugging.
        window.__autofillReport = function() { return lastReport; };
        window.__autofillRescan = function() { annotateAll('manual-rescan'); return lastReport; };

        post('script-injected');

        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', function() {
                annotateAll('DOMContentLoaded');
            }, { once: true });
        } else {
            annotateAll('annotated');
        }

        document.addEventListener('focusin', function(event) {
            var target = event.target;
            if (!target || target.tagName !== 'INPUT') { return; }
            annotateAll('focusin-rescan');
            post('focusin', { active: describe(target) });
        }, true);

        document.addEventListener('submit', function(event) {
            var target = event.target;
            var form = target && target.tagName === 'FORM' ? target : null;
            annotateAll('submit-rescan');
            post('submit', {
                formAction: form ? safeURL(form.getAttribute('action') || location.href) : '',
                formMethod: form ? (form.getAttribute('method') || 'get') : ''
            });
        }, true);

        try {
            var observer = new MutationObserver(function(mutations) {
                for (var i = 0; i < mutations.length; i++) {
                    var added = mutations[i].addedNodes;
                    for (var j = 0; j < added.length; j++) {
                        var node = added[j];
                        if (node && node.nodeType === 1 &&
                            (node.tagName === 'INPUT' || node.querySelector)) {
                            if (pendingMutationReport) { return; }
                            pendingMutationReport = true;
                            setTimeout(function() {
                                pendingMutationReport = false;
                                annotateAll('mutation-rescan');
                            }, 100);
                            return;
                        }
                    }
                }
            });
            observer.observe(document.documentElement || document.body, {
                childList: true,
                subtree: true
            });
        } catch (e) {}
    })();
    """
}

#endif
