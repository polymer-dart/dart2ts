import 'package:html5/html.dart';
import 'dart:async';

Future<HTMLLinkElement> importHtml(String href) {
  Completer c = new Completer();
  HTMLLinkElement link;
  link = (document.createElement('link') as HTMLLinkElement)
    ..rel = 'import'
    ..href = href
    ..onload = ((Event ev) => c.complete(link))
    ..onerror = ((Event ev) => c.completeError(ev));
  document.querySelector('head').appendChild(link);


  return c.future;
}
