import 'dart:js_interop';

@JS('window.location.href')
external JSString get _href;

/// The address-bar URL. `Uri.base` uses `<base href>` and drops the query string.
Uri? launchUrl() => Uri.tryParse(_href.toDart);
