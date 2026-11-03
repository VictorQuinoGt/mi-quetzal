import 'package:flutter/material.dart';

import 'dart:async';

import '../../data/repositories/installment_repository.dart';
import '../../domain/models/installment_plan.dart';
import '../../ui/accounts/installment_form_view.dart';
import '../../ui/accounts/installment_form_view_model.dart';
import '../../ui/accounts/installment_plan_view.dart';
import '../../ui/accounts/installment_plan_view_model.dart';

import '../../data/repositories/account_repository.dart';
import '../../data/repositories/movement_repository.dart';
import '../../domain/models/movement.dart';
import '../../domain/models/account.dart';
import '../../domain/models/debit_card.dart';
import '../../domain/models/account_activity.dart';
import '../../ui/categories/categories_view.dart';
import '../../ui/categories/categorize_movement_view.dart';
import '../../ui/accounts/accounts_view.dart';
import '../../ui/accounts/accounts_view_model.dart';
import '../../ui/accounts/create_account_view.dart';
import '../../ui/accounts/create_debit_card_view.dart';
import '../../ui/accounts/account_detail_view.dart';
import '../../ui/accounts/account_detail_view_model.dart';
import '../../ui/movements/movement_detail_view.dart';
import '../../ui/home/home_view.dart';
import '../../ui/movements/movements_view.dart';
import '../../ui/movements/movements_view_model.dart';
import '../../ui/movements/create_movement_view.dart';
import '../../ui/movements/create_refund_view.dart';
import '../../ui/planning/planning_view.dart';
import 'app_section.dart';
import 'app_shell_view_model.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.accountRepository,
    required this.movementRepository,
    required this.installmentRepository,
    this.enableInstallmentPolling = false,
  });
  final AccountRepository accountRepository;
  final MovementRepository movementRepository;
  final InstallmentRepository installmentRepository;
  final bool enableInstallmentPolling;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  Timer? _installmentTimer;
  final _openAccountViewModels = <AccountDetailViewModel>{};
  late final AppShellViewModel _viewModel;
  late final AccountsViewModel _accountsViewModel;
  late final MovementsViewModel _movementsViewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AppShellViewModel(
      installmentRepository: widget.installmentRepository,
    );
    WidgetsBinding.instance.addObserver(this);
    _accountsViewModel = AccountsViewModel(widget.accountRepository)..load();
    _movementsViewModel = MovementsViewModel(widget.movementRepository)..load();
    if (widget.enableInstallmentPolling) {
      _installmentTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _refreshInstallments(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshInstallments();
  }

  Future<void> _refreshInstallments() async {
    if (!mounted ||
        _accountsViewModel.isSaving ||
        _movementsViewModel.isSaving) {
      return;
    }
    await _viewModel.refreshInstallments(
      () => [
        _accountsViewModel.load,
        _movementsViewModel.load,
        for (final vm in _openAccountViewModels.toList()) vm.load,
      ],
    );
  }

  void _selectSection(AppSection section) {
    _viewModel.selectSection(section);
    unawaited(_refreshInstallments());
  }

  Future<void> _createAccount([Account? account]) async {
    if (_accountsViewModel.status != AccountsStatus.ready) return;
    _accountsViewModel.startCreate();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CreateAccountView(viewModel: _accountsViewModel, account: account),
      ),
    );
    if (created == true && mounted) {
      await _movementsViewModel.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            account == null ? 'Cuenta guardada' : 'Cuenta actualizada',
          ),
        ),
      );
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

  Future<void> _linkDebitCard(DebitCard? card, {int? initialAccountId}) async {
    if (_accountsViewModel.status != AccountsStatus.ready ||
        _accountsViewModel.bankAccounts.isEmpty) {
      return;
    }
    _accountsViewModel.startCreate();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateDebitCardView(
          viewModel: _accountsViewModel,
          card: card,
          initialAccountId: initialAccountId,
        ),
      ),
    );
    if (created == true && mounted) {
      await _movementsViewModel.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            card == null
                ? 'Tarjeta de débito vinculada'
                : 'Tarjeta de débito actualizada',
          ),
        ),
      );
    }
  }

  Future<void> _manageCategories() async {
    if (_movementsViewModel.status != MovementsStatus.ready) return;
    _movementsViewModel.startCreate();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CategoriesView(viewModel: _movementsViewModel),
      ),
    );
    if (mounted) await _accountsViewModel.load();
  }

  Future<void> _categorizeMovement(
    Movement movement, {
    MovementsViewModel? source,
  }) async {
    final vm = source ?? _movementsViewModel;
    if (vm.status != MovementsStatus.ready) return;
    final current = vm.movementById(movement.id) ?? movement;
    vm.startCreate();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CategorizeMovementView(viewModel: vm, movement: current),
      ),
    );
    if (saved == true && mounted) {
      if (source != null) await _movementsViewModel.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Categoría actualizada')));
    }
  }

  Future<void> _refundMovement(
    Movement original, {
    MovementsViewModel? source,
  }) async {
    final vm = source ?? _movementsViewModel;
    if (vm.status != MovementsStatus.ready) return;
    vm.startCreate();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CreateRefundView(viewModel: vm, original: original),
      ),
    );
    if (saved == true && mounted) {
      await _accountsViewModel.load();
      if (source != null) await _movementsViewModel.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Devolución guardada')));
    }
  }

  Future<void> _openAccountDetail(AccountDetailTarget target) async {
    final vm = AccountDetailViewModel(
      widget.movementRepository,
      target: target,
      initialName:
          (target.kind == AccountDetailKind.account
              ? _accountsViewModel.accountById(target.id)?.details.name
              : _movementsViewModel.debitCardById(target.id)?.details.name) ??
          'Detalle de cuenta',
    )..load();
    _openAccountViewModels.add(vm);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => AccountDetailView(
          viewModel: vm,
          onEdit: () async {
            if (vm.debitCard != null) {
              await _linkDebitCard(vm.debitCard);
            } else {
              await _createAccount(vm.account);
            }
            await vm.load();
          },
          onLinkDebit: () async {
            await _linkDebitCard(null, initialAccountId: vm.account?.id);
            await vm.load();
          },
          onOpenAccount: (next) async {
            await _openAccountDetail(next);
            await vm.load();
          },
          onOpenMovement: (movement) => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (context) => MovementDetailView(
                movement: movement,
                viewModel: vm.ledger,
                onCategorize: () =>
                    _categorizeMovement(movement, source: vm.ledger),
                onRefund: () => _refundMovement(movement, source: vm.ledger),
              ),
            ),
          ),
          onAddPlan: () => _editInstallment(vm, null),
          onOpenPlan: (plan) => _openInstallment(vm, plan.id),
        ),
      ),
    );
    _openAccountViewModels.remove(vm);
    vm.dispose();
  }

  Future<void> _editInstallment(
    AccountDetailViewModel accountVM,
    InstallmentPlan? plan,
  ) async {
    final form = InstallmentFormViewModel(
      widget.installmentRepository,
      ledger: accountVM.ledger,
      accountId: accountVM.account!.id,
      editing: plan,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => InstallmentFormView(viewModel: form)),
    );
    form.dispose();
    await accountVM.load();
    await _refreshInstallments();
  }

  Future<void> _openInstallment(
    AccountDetailViewModel accountVM,
    int id,
  ) async {
    final vm = InstallmentPlanViewModel(
      widget.installmentRepository,
      planId: id,
      ledger: accountVM.ledger,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InstallmentPlanView(
          viewModel: vm,
          onEdit: (plan) => _editInstallment(accountVM, plan),
          onOpenMovement: (movement) => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => MovementDetailView(
                movement: movement,
                viewModel: accountVM.ledger,
                onCategorize: () =>
                    _categorizeMovement(movement, source: accountVM.ledger),
                onRefund: () =>
                    _refundMovement(movement, source: accountVM.ledger),
              ),
            ),
          ),
        ),
      ),
    );
    vm.dispose();
    await accountVM.load();
    await _refreshInstallments();
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
    _installmentTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _accountsViewModel.dispose();
    _movementsViewModel.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Widget _page(AppSection section) => switch (section) {
    AppSection.home => HomeView(
      onNavigate: _selectSection,
      viewModel: _movementsViewModel,
    ),
    AppSection.movements => MovementsView(
      viewModel: _movementsViewModel,
      onCreate: _createMovement,
      onOpenAccounts: () => _selectSection(AppSection.accounts),
      onManageCategories: _manageCategories,
      onCategorize: _categorizeMovement,
      onRefund: _refundMovement,
    ),
    AppSection.accounts => AccountsView(
      viewModel: _accountsViewModel,
      onCreate: _createAccount,
      onOpen: _openAccountDetail,
      onManageInstitutions: _manageCategories,
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
                        onDestinationSelected: (index) =>
                            _selectSection(_destinations[index].section),
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
                      onDestinationSelected: (index) =>
                          _selectSection(_destinations[index].section),
                      destinations: [
                        for (final destination in _destinations)
                          NavigationDestination(
                            icon: Icon(destination.icon),
                            label: destination.label,
                          ),
                      ],
                    ),
              floatingActionButton: _viewModel.section == AppSection.accounts
                  ? null
                  : FloatingActionButton.extended(
                      onPressed:
                          (_movementsViewModel.status == MovementsStatus.ready
                          ? _createMovement
                          : null),
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar'),
                      tooltip: 'Registrar movimiento',
                    ),
            );
          },
        );
      },
    );
  }
}
