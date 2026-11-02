import 'package:flutter/material.dart';

import '../../data/repositories/account_repository.dart';
import '../../data/repositories/movement_repository.dart';
import '../../ui/accounts/accounts_view.dart';
import '../../ui/accounts/accounts_view_model.dart';
import '../../ui/accounts/create_account_view.dart';
import '../../ui/home/home_view.dart';
import '../../ui/movements/movements_view.dart';
import '../../ui/movements/movements_view_model.dart';
import '../../ui/movements/create_movement_view.dart';
import '../../ui/planning/planning_view.dart';
import 'app_section.dart';
import 'app_shell_view_model.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.accountRepository,
    required this.movementRepository,
  });
  final AccountRepository accountRepository;
  final MovementRepository movementRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _viewModel = AppShellViewModel();
  late final AccountsViewModel _accountsViewModel;
  late final MovementsViewModel _movementsViewModel;

  @override
  void initState() {
    super.initState();
    _accountsViewModel = AccountsViewModel(widget.accountRepository)..load();
    _movementsViewModel = MovementsViewModel(widget.movementRepository)..load();
  }

  Future<void> _createAccount() async {
    if (_accountsViewModel.status != AccountsStatus.ready) return;
    _accountsViewModel.startCreate();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateAccountView(viewModel: _accountsViewModel),
      ),
    );
    if (created == true && mounted) {
      await _movementsViewModel.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cuenta guardada')));
    }
  }

  Future<void> _createMovement() async {
    if (_movementsViewModel.status != MovementsStatus.ready) return;
    if (_movementsViewModel.accounts.isEmpty) {
      _viewModel.selectSection(AppSection.accounts);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero agrega una cuenta')),
      );
      return;
    }
    _movementsViewModel.startCreate();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CreateMovementView(viewModel: _movementsViewModel),
      ),
    );
    if (created == true && mounted) {
      _viewModel.selectSection(AppSection.movements);
      await _accountsViewModel.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Movimiento guardado')));
    }
  }

  static const _destinations = [
    (section: AppSection.home, label: 'Inicio', icon: Icons.home_outlined),
    (
      section: AppSection.movements,
      label: 'Movimientos',
      icon: Icons.swap_vert_rounded,
    ),
    (
      section: AppSection.accounts,
      label: 'Cuentas',
      icon: Icons.account_balance_wallet_outlined,
    ),
    (
      section: AppSection.planning,
      label: 'Planificación',
      icon: Icons.calendar_month_outlined,
    ),
  ];

  @override
  void dispose() {
    _accountsViewModel.dispose();
    _movementsViewModel.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Widget _page(AppSection section) => switch (section) {
    AppSection.home => HomeView(onNavigate: _viewModel.selectSection),
    AppSection.movements => MovementsView(
      viewModel: _movementsViewModel,
      onCreate: _createMovement,
      onOpenAccounts: () => _viewModel.selectSection(AppSection.accounts),
    ),
    AppSection.accounts => AccountsView(
      viewModel: _accountsViewModel,
      onCreate: _createAccount,
    ),
    AppSection.planning => const PlanningView(),
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _viewModel,
        _accountsViewModel,
        _movementsViewModel,
      ]),
      builder: (context, _) {
        final selectedIndex = AppSection.values.indexOf(_viewModel.section);
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 840;
            return Scaffold(
              appBar: AppBar(
                title: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.spa_outlined),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Mi Quetzal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              body: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide) ...[
                      NavigationRail(
                        labelType: NavigationRailLabelType.all,
                        selectedIndex: selectedIndex,
                        onDestinationSelected: (index) => _viewModel
                            .selectSection(_destinations[index].section),
                        destinations: [
                          for (final destination in _destinations)
                            NavigationRailDestination(
                              icon: Icon(destination.icon),
                              label: Text(destination.label),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                    ],
                    Expanded(child: _page(_viewModel.section)),
                  ],
                ),
              ),
              bottomNavigationBar: wide
                  ? null
                  : NavigationBar(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) => _viewModel
                          .selectSection(_destinations[index].section),
                      destinations: [
                        for (final destination in _destinations)
                          NavigationDestination(
                            icon: Icon(destination.icon),
                            label: destination.label,
                          ),
                      ],
                    ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: _viewModel.section == AppSection.accounts
                    ? (_accountsViewModel.status == AccountsStatus.ready
                          ? _createAccount
                          : null)
                    : (_movementsViewModel.status == MovementsStatus.ready
                          ? _createMovement
                          : null),
                icon: const Icon(Icons.add),
                label: Text(
                  _viewModel.section == AppSection.accounts
                      ? 'Agregar cuenta'
                      : 'Registrar',
                ),
                tooltip: _viewModel.section == AppSection.accounts
                    ? 'Agregar cuenta'
                    : 'Registrar movimiento',
              ),
            );
          },
        );
      },
    );
  }
}
