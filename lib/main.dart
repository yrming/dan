import 'package:dan/app/view/app.dart';
import 'package:dan/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
