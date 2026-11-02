import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/app/navigation/app_section.dart';
import 'package:mi_quetzal/app/navigation/app_shell_view_model.dart';

void main() {
  test('Comienza en Inicio y notifica solo al cambiar de sección', () {
    final viewModel = AppShellViewModel();
    addTearDown(viewModel.dispose);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    expect(viewModel.section, AppSection.home);
    viewModel.selectSection(AppSection.home);
    expect(notifications, 0);

    viewModel.selectSection(AppSection.accounts);
    expect(viewModel.section, AppSection.accounts);
    expect(notifications, 1);

    viewModel.selectSection(AppSection.accounts);
    expect(notifications, 1);

    viewModel.selectSection(AppSection.home);
    expect(viewModel.section, AppSection.home);
    expect(notifications, 2);
  });
}
