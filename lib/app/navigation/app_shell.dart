import 'package:flutter/material.dart';

import 'dart:async';

import '../../data/repositories/installment_repository.dart';
import '../../domain/models/installment_plan.dart';
import '../../domain/models/ledger_snapshot.dart';
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
import '../../ui/movements/movement_labels.dart';
import '../../ui/movements/create_refund_view.dart';
import '../../ui/settings/settings_view.dart';
import '../../ui/settings/financial_institutions_view.dart';
import 'app_section.dart';
import 'app_shell_view_model.dart';
import '../appearance_view_model.dart';
import '../../domain/models/app_appearance.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.accountRepository,
    required this.movementRepository,
    required this.installmentRepository,
    required this.appearanceViewModel,
    this.enableInstallmentPolling = false,
  });
  final AccountRepository accountRepository;
  final MovementRepository movementRepository;
  final InstallmentRepository installmentRepository;
  final AppearanceViewModel appearanceViewModel;
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

  bool get _hasPendingWrite =>
      _accountsViewModel.isSaving ||
      _movementsViewModel.isSaving ||
      _openAccountViewModels.any((vm) => vm.ledger.isSaving);

  Future<void> _refreshInstallments() async {
    if (!mounted || _hasPendingWrite) return;
    final snapshot = await _viewModel.refreshInstallments();
    if (mounted && snapshot != null && !_hasPendingWrite) {
      _publishSnapshot(snapshot, invalidateRefresh: false);
    }
  }

  void _publishSnapshot(
    LedgerSnapshot snapshot, {
    bool invalidateRefresh = true,
  }) {
    if (invalidateRefresh) _viewModel.invalidateRefresh();
    _movementsViewModel.applySnapshot(snapshot);
    _accountsViewModel.applySnapshot(snapshot);
    for (final detail in _openAccountViewModels.toList()) {
      detail.ledger.applySnapshot(snapshot);
    }
  }

  void _selectSection(AppSection section) {
    if (_viewModel.section == section) return;
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

  Future<void> _createMovement({AccountDetailViewModel? accountContext}) async {
    final vm = accountContext?.ledger ?? _movementsViewModel;
    if (vm.status != MovementsStatus.ready || vm.isSaving) return;
    if (vm.accounts.isEmpty) {
      _viewModel.selectSection(AppSection.accounts);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero agrega una cuenta')),
      );
      return;
    }
    MovementType? initialType;
    if (accountContext != null) {
      initialType = await showModalBottomSheet<MovementType>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    'Registrar en ${accountContext.name}',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                for (final type in vm.operationsFor(accountContext.target))
                  ListTile(
                    leading: Icon(switch (type) {
                      MovementType.expense => Icons.receipt_long_outlined,
                      MovementType.creditPayment => Icons.payments_outlined,
                      MovementType.income => Icons.south_west,
                      _ => Icons.swap_horiz,
                    }),
                    title: Text(type.shortLabel),
                    onTap: () => Navigator.of(sheetContext).pop(type),
                  ),
              ],
            ),
          ),
        ),
      );
      if (initialType == null ||
          !mounted ||
          vm.status != MovementsStatus.ready) {
        return;
      }
    }
    vm.startCreate();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateMovementView(
          viewModel: vm,
          target: accountContext?.target,
          initialType: initialType,
          onCatalogChanged: () => _publishSnapshot(vm.snapshot!),
        ),
      ),
    );
    if (mounted && vm.snapshot != null) {
      _publishSnapshot(vm.snapshot!);
    }
    if (created == true && mounted) {
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
    await _movementsViewModel.load();
    if (!mounted || _movementsViewModel.status != MovementsStatus.ready) return;
    _movementsViewModel.startCreate();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CategoriesView(viewModel: _movementsViewModel),
      ),
    );
    if (mounted && _movementsViewModel.snapshot != null) {
      _publishSnapshot(_movementsViewModel.snapshot!);
    }
  }

  Future<void> _manageInstitutions() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            FinancialInstitutionsView(viewModel: _accountsViewModel),
      ),
    );
    if (!mounted) return;
    await _movementsViewModel.load();
    if (mounted && _movementsViewModel.snapshot != null) {
      _publishSnapshot(_movementsViewModel.snapshot!);
    }
  }

  Future<void> _openHistory() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Historial general')),
        body: SafeArea(
          child: MovementsView(
            viewModel: _movementsViewModel,
            onOpenAccounts: () {
              Navigator.of(context).pop();
              _selectSection(AppSection.accounts);
            },
            onCategorize: _categorizeMovement,
            onRefund: _refundMovement,
          ),
        ),
      ),
    ),
  );

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
        builder: (context) => CategorizeMovementView(
          viewModel: vm,
          movement: current,
          onCatalogChanged: () => _publishSnapshot(vm.snapshot!),
        ),
      ),
    );
    if (saved == true && mounted) {
      _publishSnapshot(vm.snapshot!);
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
      _publishSnapshot(vm.snapshot!);
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
          onCreateMovement: () => _createMovement(accountContext: vm),
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
    if (mounted && accountVM.ledger.snapshot != null) {
      _publishSnapshot(accountVM.ledger.snapshot!);
    }
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
    if (mounted && accountVM.ledger.snapshot != null) {
      _publishSnapshot(accountVM.ledger.snapshot!);
    }
  }

  static const _destinations = [
    (section: AppSection.home, label: 'Inicio', icon: Icons.home_outlined),
    (
      section: AppSection.accounts,
      label: 'Cuentas',
      icon: Icons.account_balance_wallet_outlined,
    ),
    (
      section: AppSection.settings,
      label: 'Ajustes',
      icon: Icons.settings_outlined,
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
      onAccounts: () => _selectSection(AppSection.accounts),
      onHistory: _openHistory,
      onOpenAccount: (id) =>
          _openAccountDetail(AccountDetailTarget.account(id)),
      viewModel: _movementsViewModel,
    ),
    AppSection.accounts => AccountsView(
      viewModel: _accountsViewModel,
      onCreate: _createAccount,
      onOpen: _openAccountDetail,
    ),
    AppSection.settings => SettingsView(
      appearance: widget.appearanceViewModel,
      canManage:
          _movementsViewModel.status == MovementsStatus.ready &&
          _accountsViewModel.status == AccountsStatus.ready,
      onCategories: _manageCategories,
      onInstitutions: _manageInstitutions,
    ),
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
                actions: [
                  PopupMenuButton<AppAppearance>(
                    tooltip: 'Apariencia',
                    enabled: !widget.appearanceViewModel.isSaving,
                    initialValue: widget.appearanceViewModel.appearance,
                    icon: Icon(switch (widget.appearanceViewModel.appearance) {
                      AppAppearance.system => Icons.brightness_auto_outlined,
                      AppAppearance.light => Icons.light_mode_outlined,
                      AppAppearance.dark => Icons.dark_mode_outlined,
                    }),
                    onSelected: (appearance) async {
                      await widget.appearanceViewModel.select(appearance);
                      if (!mounted || !context.mounted) return;
                      final error = widget.appearanceViewModel.error;
                      if (error != null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
                    itemBuilder: (_) => [
                      for (final appearance in AppAppearance.values)
                        CheckedPopupMenuItem(
                          value: appearance,
                          checked:
                              widget.appearanceViewModel.appearance ==
                              appearance,
                          child: Text(switch (appearance) {
                            AppAppearance.system => 'Sistema',
                            AppAppearance.light => 'Claro',
                            AppAppearance.dark => 'Oscuro',
                          }),
                        ),
                    ],
                  ),
                ],
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
            );
          },
        );
      },
    );
  }
}
