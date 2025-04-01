import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import '../services/api.dart';

class OperatorReportsScreen extends StatefulWidget {
  const OperatorReportsScreen({Key? key}) : super(key: key);

  @override
  _OperatorReportsScreenState createState() => _OperatorReportsScreenState();
}

class _OperatorReportsScreenState extends State<OperatorReportsScreen> {
  bool loading = false;
  bool initialLoad = true;
  List<Trip> trips = [];
  List<OperatorProfile> operators = [];
  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();
  OperatorProfile? selectedOperator;
  bool showOperators = false;
  String searchTerm = '';
  final TextEditingController searchController = TextEditingController();

  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color inputIconColor = Colors.grey.shade500;
  final Color borderColor = Colors.grey.shade300;
  final Color errorColor = Colors.red.shade700;
  final Color successColor = Colors.green.shade600;
  final Color filterBackgroundColor = Colors.white;

  final DateFormat _displayDateFormat = DateFormat("d MMM, yyyy", 'es');
  final DateFormat _apiDateFormat = DateFormat("yyyy-MM-dd");
  final currencyFormatter = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  @override
  void initState() {
    super.initState();
    _loadOperators();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOperators() async {
    try {
      final operatorService = OperatorService();
      final data = await operatorService.getAllOperators();
      if (mounted) {
        setState(() {
          operators = data;
          operators.sort(
            (a, b) => '${a.first_name} ${a.last_name}'.compareTo(
              '${b.first_name} ${b.last_name}',
            ),
          );
        });
      }
    } catch (error) {
      developer.log('Error al cargar operadores: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar lista de operadores'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> _fetchTrips() async {
    if (selectedOperator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, seleccione un operador'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    setState(() {
      loading = true;
      initialLoad = false;
    });

    try {
      final analyticsService = AnalyticsService();
      final data = await analyticsService.getOperatorCompletedTrips(
        _apiDateFormat.format(startDate),
        _apiDateFormat.format(endDate),
        selectedOperator!.id,
      );

      if (mounted) {
        setState(() {
          trips = data.map((tripData) => Trip.fromJson(tripData)).toList();
          trips.sort(
            (a, b) => DateTime.parse(
              b.createdAt,
            ).compareTo(DateTime.parse(a.createdAt)),
          );
          loading = false;
        });
      }
    } catch (error) {
      developer.log('Error al obtener viajes: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron cargar los viajes'),
            backgroundColor: errorColor,
          ),
        );
        setState(() {
          loading = false;
          trips = [];
        });
      }
    }
  }

  List<OperatorProfile> get filteredOperators {
    if (searchTerm.isEmpty) {
      return operators;
    }
    return operators.where((operator) {
      final fullName =
          '${operator.first_name} ${operator.last_name}'.toLowerCase();
      return fullName.contains(searchTerm.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Reportes por Operador',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [_buildFiltersSection(), Expanded(child: _buildTripsList())],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: filterBackgroundColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFilterSelectorButton(
                  icon: LucideIcons.calendarDays,
                  label: _displayDateFormat.format(startDate),
                  onTap: () => _selectDate(context, true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFilterSelectorButton(
                  icon: LucideIcons.calendarDays,
                  label: _displayDateFormat.format(endDate),
                  onTap: () => _selectDate(context, false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterSelectorButton(
                  icon: LucideIcons.user,
                  label:
                      selectedOperator != null
                          ? '${selectedOperator!.first_name} ${selectedOperator!.last_name}'
                          : 'Seleccionar Operador',
                  isSelected: selectedOperator != null,
                  onTap: _showOperatorSelectionModal,
                  onClear:
                      selectedOperator != null
                          ? () => setState(() => selectedOperator = null)
                          : null,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  icon:
                      loading
                          ? Container(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Icon(LucideIcons.search, size: 18),
                  label: Text('Buscar'),
                  onPressed: loading ? null : _fetchTrips,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),

          if (showOperators)
            _buildSelectionModal<OperatorProfile>(
              context: context,
              title: 'Seleccionar Operador',
              items: operators,
              filteredItemsBuilder:
                  (query) =>
                      operators.where((op) {
                        final name =
                            '${op.first_name} ${op.last_name}'.toLowerCase();
                        return name.contains(query.toLowerCase());
                      }).toList(),
              itemBuilder:
                  (operator) => ListTile(
                    title: Text('${operator.first_name} ${operator.last_name}'),
                    selected: selectedOperator?.id == operator.id,
                    selectedTileColor: primaryColor.withOpacity(0.1),
                    onTap: () {
                      setState(() {
                        selectedOperator = operator;
                        showOperators = false;
                        searchController.clear();
                      });
                    },
                  ),
              searchController: searchController,
              onSearchChanged: (value) => setState(() {}),
              onClose: () => setState(() => showOperators = false),
              onClear: () => setState(() => selectedOperator = null),
              selectedItem: selectedOperator,
              itemNameBuilder: (op) => '${op.first_name} ${op.last_name}',
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSelectorButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = true,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: inputIconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      isSelected
                          ? textColorPrimary
                          : textColorSecondary.withOpacity(0.7),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (onClear != null)
              InkWell(
                onTap: onClear,
                child: Icon(
                  LucideIcons.circleX,
                  size: 14,
                  color: errorColor.withOpacity(0.7),
                ),
              )
            else
              Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: textColorSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionModal<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required List<T> Function(String) filteredItemsBuilder,
    required Widget Function(T) itemBuilder,
    required TextEditingController searchController,
    required ValueChanged<String> onSearchChanged,
    required VoidCallback onClose,
    required VoidCallback onClear,
    required T? selectedItem,
    required String Function(T) itemNameBuilder,
  }) {
    final filteredItems = filteredItemsBuilder(searchController.text);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                decoration: BoxDecoration(
                  color: scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textColorPrimary,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              LucideIcons.x,
                              color: textColorSecondary,
                            ),
                            onPressed: onClose,
                            tooltip: 'Cerrar',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Buscar...',
                          prefixIcon: Icon(
                            LucideIcons.search,
                            size: 18,
                            color: textColorSecondary,
                          ),
                          suffixIcon:
                              searchController.text.isNotEmpty
                                  ? IconButton(
                                    icon: Icon(
                                      LucideIcons.circleX,
                                      size: 16,
                                      color: textColorSecondary,
                                    ),
                                    onPressed: () {
                                      searchController.clear();
                                      onSearchChanged('');
                                    },
                                  )
                                  : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text(
                        'Quitar Selección',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: textColorSecondary,
                        ),
                      ),
                      selected: selectedItem == null,
                      selectedTileColor: primaryColor.withOpacity(0.05),
                      onTap: () {
                        onClear();
                        onClose();
                      },
                    ),
                    Divider(height: 1, color: borderColor),
                    Flexible(
                      child:
                          filteredItems.isEmpty
                              ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'No se encontraron coincidencias',
                                    style: TextStyle(color: textColorSecondary),
                                  ),
                                ),
                              )
                              : ListView.separated(
                                shrinkWrap: true,
                                itemCount: filteredItems.length,
                                itemBuilder:
                                    (context, index) =>
                                        itemBuilder(filteredItems[index]),
                                separatorBuilder:
                                    (context, index) => Divider(
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                      color: borderColor.withOpacity(0.5),
                                    ),
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripsList() {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (initialLoad) {
      return _buildEmptyState(
        icon: LucideIcons.searchCode,
        title: 'Realizar Búsqueda',
        message:
            'Seleccione un operador y un rango de fechas para ver los reportes.',
      );
    }

    if (trips.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.fileX2,
        title: 'Sin Resultados',
        message: 'No se encontraron viajes para los filtros seleccionados.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        return _buildTripCard(trips[index]);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(32.0),
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColorSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTripCard(Trip trip) {
    final driverName =
        trip.driver_profiles != null
            ? '${trip.driver_profiles!['first_name'] ?? ''} ${trip.driver_profiles!['last_name'] ?? ''}'
                .trim()
            : 'No asignado';
    final operatorName =
        trip.operator_profiles != null
            ? '${trip.operator_profiles!['first_name'] ?? ''} ${trip.operator_profiles!['last_name'] ?? ''}'
                .trim()
            : 'No asignado';

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.calendar, size: 14, color: primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      _displayDateFormat.format(DateTime.parse(trip.createdAt)),
                      style: TextStyle(
                        fontSize: 13,
                        color: textColorSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  currencyFormatter.format(trip.price ?? 0.0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            Divider(height: 20, color: borderColor.withOpacity(0.7)),

            _buildDetailRow(
              icon: LucideIcons.mapPin,
              label: 'Origen:',
              value: trip.origin,
            ),
            _buildDetailRow(
              icon: LucideIcons.flag,
              label: 'Destino:',
              value: trip.destination,
            ),
            _buildDetailRow(
              icon: LucideIcons.shipWheel,
              label: 'Chofer:',
              value: driverName,
            ),
            _buildDetailRow(
              icon: LucideIcons.userCheck,
              label: 'Operador:',
              value: operatorName,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: textColorSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 65,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: textColorSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: TextStyle(fontSize: 13, color: textColorPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? startDate : endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: textColorPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          if (picked.isAfter(endDate)) {
            startDate = picked;
            endDate = picked;
          } else {
            startDate = picked;
          }
        } else {
          if (picked.isBefore(startDate)) {
            endDate = picked;
            startDate = picked;
          } else {
            endDate = picked;
          }
        }
      });
    }
  }

  void _showOperatorSelectionModal() {
    setState(() {
      searchController.clear();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            final List<OperatorProfile> filteredModalOperators =
                operators.where((operator) {
                  final fullName =
                      '${operator.first_name} ${operator.last_name}'
                          .toLowerCase();
                  final query = searchController.text.toLowerCase();
                  return fullName.contains(query);
                }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seleccionar Operador',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColorPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.x, color: textColorSecondary),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      modalSetState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre...',
                      prefixIcon: Icon(
                        LucideIcons.search,
                        size: 20,
                        color: textColorSecondary,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      LucideIcons.users,
                      color:
                          selectedOperator == null
                              ? primaryColor
                              : textColorSecondary,
                    ),
                    title: Text(
                      'Todos los Operadores',
                      style: TextStyle(
                        fontWeight:
                            selectedOperator == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        selectedOperator = null;
                      });
                      Navigator.pop(context);
                    },
                    dense: true,
                    selected: selectedOperator == null,
                    selectedTileColor: primaryColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Divider(color: borderColor.withOpacity(0.5)),
                  Expanded(
                    child:
                        filteredModalOperators.isEmpty
                            ? Center(
                              child: Text(
                                'No se encontraron operadores',
                                style: TextStyle(color: textColorSecondary),
                              ),
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredModalOperators.length,
                              itemBuilder: (context, index) {
                                final operator = filteredModalOperators[index];
                                final bool isCurrentlySelected =
                                    selectedOperator?.id == operator.id;
                                return ListTile(
                                  leading: Icon(
                                    LucideIcons.user,
                                    color:
                                        isCurrentlySelected
                                            ? primaryColor
                                            : textColorSecondary,
                                  ),
                                  title: Text(
                                    '${operator.first_name} ${operator.last_name}',
                                  ),
                                  onTap: () {
                                    setState(() {
                                      selectedOperator = operator;
                                    });
                                    Navigator.pop(context);
                                  },
                                  dense: true,
                                  selected: isCurrentlySelected,
                                  selectedTileColor: primaryColor.withOpacity(
                                    0.1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                );
                              },
                            ),
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
