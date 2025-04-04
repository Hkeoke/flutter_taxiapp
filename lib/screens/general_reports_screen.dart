// import 'package:flutter/material.dart' as flutter; // Puedes eliminar esta si no necesitas el prefijo
import 'package:flutter/material.dart'; // Mantén esta importación normal
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border; // Oculta Border de excel
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../widgets/sidebar.dart';

class GeneralReportsScreen extends StatefulWidget {
  const GeneralReportsScreen({Key? key}) : super(key: key);

  @override
  _GeneralReportsScreenState createState() => _GeneralReportsScreenState();
}

class _GeneralReportsScreenState extends State<GeneralReportsScreen> {
  bool isSidebarVisible = false;
  bool loading = false;
  bool refreshing = false;
  List<Trip> trips = [];
  List<DriverProfile> drivers = [];
  List<OperatorProfile> operators = [];
  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();
  int? selectedYear;
  DriverProfile? selectedDriver;
  OperatorProfile? selectedOperator;
  bool showDrivers = false;
  bool showOperators = false;
  String driverSearchTerm = '';
  String operatorSearchTerm = '';
  double totalAmount = 0.0;
  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color borderColor = Colors.grey.shade300;
  final Color errorColor = Colors.red.shade700;
  final Color successColor = Colors.green.shade600;
  final Color filterBackgroundColor = Colors.white;
  final Color totalSectionBgColor = Colors.grey.shade200;
  final DateFormat _displayDateFormat = DateFormat("d MMM, yyyy", 'es');
  final DateFormat _apiDateFormat = DateFormat("yyyy-MM-dd");
  final currencyFormatter = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );
  final DateFormat _pdfExcelDateFormat = DateFormat('dd/MM/yyyy', 'es');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchDriversAndOperators();
    await _fetchTrips();
  }

  Future<void> _fetchDriversAndOperators() async {
    try {
      final driverService = DriverService();
      final operatorService = OperatorService();
      final fetchedDrivers = await driverService.getAllDrivers();
      final fetchedOperators = await operatorService.getAllOperators();

      if (mounted) {
        setState(() {
          drivers = fetchedDrivers;
          operators = fetchedOperators;
          drivers.sort(
            (a, b) => '${a.firstName} ${a.lastName}'.compareTo(
              '${b.firstName} ${b.lastName}',
            ),
          );
          operators.sort(
            (a, b) => '${a.first_name} ${a.last_name}'.compareTo(
              '${b.first_name} ${b.last_name}',
            ),
          );
        });
      }
    } catch (error) {
      developer.log('Error cargando conductores/operadores: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar listas de personal'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> _fetchTrips({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        loading = true;
      });
    } else {
      setState(() {
        refreshing = true;
      });
    }

    try {
      final tripService = TripService();
      final response = await tripService.getTrips(
        startDate: _apiDateFormat.format(startDate),
        endDate: _apiDateFormat.format(endDate),
        driverId: selectedDriver?.id,
        operatorId: selectedOperator?.id,
        year: selectedYear,
      );

      if (mounted) {
        setState(() {
          trips = [];
          trips.sort(
            (a, b) => DateTime.parse(
              b.createdAt,
            ).compareTo(DateTime.parse(a.createdAt)),
          );
          _calculateTotal();
          loading = false;
          refreshing = false;
        });
      }
    } catch (error) {
      developer.log('Error cargando viajes: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron cargar los viajes'),
            backgroundColor: errorColor,
          ),
        );
        setState(() {
          loading = false;
          refreshing = false;
          trips = [];
          totalAmount = 0.0;
        });
      }
    }
  }

  void _calculateTotal() {
    totalAmount = trips.fold(0.0, (sum, trip) => sum + (trip.price ?? 0.0));
  }

  Future<bool> _requestStoragePermission() async {
    return true;
  }

  Future<void> _handleExportPDF() async {
    if (trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay datos para exportar'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final pdf = pw.Document();
      final pw.TextStyle headerStyle = pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
      );
      final pw.TextStyle cellStyle = const pw.TextStyle(fontSize: 9);
      final pw.EdgeInsets cellPadding = const pw.EdgeInsets.all(4);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerLeft,
              margin: const pw.EdgeInsets.only(bottom: 10.0),
              child: pw.Text(
                'Reporte General de Viajes',
                style: pw.Theme.of(context).header2,
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10.0),
              child: pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: pw.Theme.of(context).header0,
              ),
            );
          },
          build: (pw.Context context) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Periodo: ${_displayDateFormat.format(startDate)} - ${_displayDateFormat.format(endDate)}',
                    style: cellStyle,
                  ),
                  if (selectedYear != null)
                    pw.Text('Año: $selectedYear', style: cellStyle),
                  if (selectedDriver != null)
                    pw.Text(
                      'Chofer: ${selectedDriver!.firstName} ${selectedDriver!.lastName}',
                      style: cellStyle,
                    ),
                  if (selectedOperator != null)
                    pw.Text(
                      'Operador: ${selectedOperator!.first_name} ${selectedOperator!.last_name}',
                      style: cellStyle,
                    ),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Table.fromTextArray(
                headerStyle: headerStyle,
                cellStyle: cellStyle,
                cellPadding: cellPadding,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                headers: [
                  'Fecha',
                  'Origen',
                  'Destino',
                  'Chofer',
                  'Operador',
                  'Precio',
                ],
                data:
                    trips.map((trip) {
                      final driverName =
                          trip.driver_profiles != null
                              ? '${trip.driver_profiles!['first_name']} ${trip.driver_profiles!['last_name']}'
                              : 'N/A';
                      final operatorName =
                          trip.operator_profiles != null
                              ? '${trip.operator_profiles!['first_name']} ${trip.operator_profiles!['last_name']}'
                              : 'N/A';
                      return [
                        _pdfExcelDateFormat.format(
                          DateTime.parse(trip.createdAt),
                        ),
                        trip.origin ?? 'N/A',
                        trip.destination ?? 'N/A',
                        driverName,
                        operatorName,
                        currencyFormatter.format(trip.price ?? 0.0),
                      ];
                    }).toList(),
                columnWidths: {
                  0: const pw.FixedColumnWidth(55),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                  5: const pw.FixedColumnWidth(50),
                },
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {5: pw.Alignment.centerRight},
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total General: ${currencyFormatter.format(totalAmount)}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Reporte_Viajes_$timestamp.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Reporte General de Viajes');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generado y listo para compartir'),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (error) {
      developer.log('Error al generar PDF: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo generar el PDF: $error'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          loading = false;
        });
    }
  }

  Future<void> _handleExportExcel() async {
    if (trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay datos para exportar'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }
    setState(() {
      loading = true;
    });

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Reporte Viajes'];

      CellStyle headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#FFDDDDDD'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );
      CellStyle totalLabelStyle = CellStyle(bold: true);
      CellStyle totalValueStyle = CellStyle(
        bold: true,
        numberFormat: NumFormat.defaultNumeric,
      );
      CellStyle currencyStyle = CellStyle(
        numberFormat: NumFormat.defaultNumeric,
      );
      CellStyle dateStyle = CellStyle(numberFormat: NumFormat.defaultDateTime);

      sheet.appendRow([
        TextCellValue('Fecha'),
        TextCellValue('Origen'),
        TextCellValue('Destino'),
        TextCellValue('Chofer'),
        TextCellValue('Operador'),
        TextCellValue('Precio'),
      ]);
      for (var i = 0; i < 6; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = headerStyle;
      }

      for (var trip in trips) {
        final driverName =
            trip.driver_profiles != null
                ? '${trip.driver_profiles!['first_name']} ${trip.driver_profiles!['last_name']}'
                : 'N/A';
        final operatorName =
            trip.operator_profiles != null
                ? '${trip.operator_profiles!['first_name']} ${trip.operator_profiles!['last_name']}'
                : 'N/A';

        sheet.appendRow([
          TextCellValue(
            _pdfExcelDateFormat.format(DateTime.parse(trip.createdAt)),
          ),
          TextCellValue(trip.origin ?? 'N/A'),
          TextCellValue(trip.destination ?? 'N/A'),
          TextCellValue(driverName),
          TextCellValue(operatorName),
          DoubleCellValue(trip.price ?? 0.0),
        ]);
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: 5,
                rowIndex: sheet.maxRows - 1,
              ),
            )
            .cellStyle = currencyStyle;
      }

      sheet.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Total General:'),
        DoubleCellValue(totalAmount),
      ]);
      sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: 4,
              rowIndex: sheet.maxRows - 1,
            ),
          )
          .cellStyle = totalLabelStyle;
      sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: 5,
              rowIndex: sheet.maxRows - 1,
            ),
          )
          .cellStyle = totalValueStyle;

      sheet.setColumnWidth(0, 12.0);
      sheet.setColumnWidth(1, 25.0);
      sheet.setColumnWidth(2, 25.0);
      sheet.setColumnWidth(3, 20.0);
      sheet.setColumnWidth(4, 20.0);
      sheet.setColumnWidth(5, 15.0);

      final output = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Reporte_Viajes_$timestamp.xlsx';
      final fileBytes = excel.save(fileName: fileName);
      if (fileBytes == null)
        throw Exception("Error al codificar el archivo Excel.");

      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(fileBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Reporte General de Viajes');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel generado y listo para compartir'),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (error) {
      developer.log('Error al generar Excel: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo generar el Excel: $error'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Reportes Generales',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        leading: IconButton(
          icon: Icon(LucideIcons.menu, color: iconColor),
          onPressed: () => setState(() => isSidebarVisible = true),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.refreshCw, color: primaryColor, size: 20),
            tooltip: 'Refrescar Datos',
            onPressed:
                loading || refreshing
                    ? null
                    : () => _fetchTrips(isRefresh: true),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildFiltersSection(),
              _buildTotalSection(),
              Expanded(child: _buildTripsList()),
            ],
          ),

          if (showDrivers)
            _buildSelectionModal(
              title: 'Seleccionar Chofer',
              items: drivers,
              filteredItemsBuilder:
                  (searchTerm) =>
                      drivers
                          .where(
                            (d) => '${d.firstName} ${d.lastName}'
                                .toLowerCase()
                                .contains(searchTerm.toLowerCase()),
                          )
                          .toList(),
              itemBuilder:
                  (item) => ListTile(
                    title: Text('${item.firstName} ${item.lastName}'),
                    selected: selectedDriver?.id == item.id,
                    onTap: () {
                      setState(() {
                        selectedDriver =
                            (selectedDriver?.id == item.id) ? null : item;
                        showDrivers = false;
                      });
                    },
                  ),
              onClose: () => setState(() => showDrivers = false),
              onClear: () => setState(() => selectedDriver = null),
              searchController: TextEditingController(text: driverSearchTerm),
              onSearchChanged:
                  (value) => setState(() => driverSearchTerm = value),
              selectedItem: selectedDriver,
              itemNameBuilder: (item) => '${item.firstName} ${item.lastName}',
            ),

          if (showOperators)
            _buildSelectionModal(
              title: 'Seleccionar Operador',
              items: operators,
              filteredItemsBuilder:
                  (searchTerm) =>
                      operators
                          .where(
                            (o) => '${o.first_name} ${o.last_name}'
                                .toLowerCase()
                                .contains(searchTerm.toLowerCase()),
                          )
                          .toList(),
              itemBuilder:
                  (item) => ListTile(
                    title: Text('${item.first_name} ${item.last_name}'),
                    selected: selectedOperator?.id == item.id,
                    onTap: () {
                      setState(() {
                        selectedOperator =
                            (selectedOperator?.id == item.id) ? null : item;
                        showOperators = false;
                      });
                    },
                  ),
              onClose: () => setState(() => showOperators = false),
              onClear: () => setState(() => selectedOperator = null),
              searchController: TextEditingController(text: operatorSearchTerm),
              onSearchChanged:
                  (value) => setState(() => operatorSearchTerm = value),
              selectedItem: selectedOperator,
              itemNameBuilder: (item) => '${item.first_name} ${item.last_name}',
            ),

          if (isSidebarVisible)
            Positioned.fill(
              child: Sidebar(
                isVisible: isSidebarVisible,
                onClose: () => setState(() => isSidebarVisible = false),
                role: 'admin',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: filterBackgroundColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12.0,
            runSpacing: 10.0,
            children: [
              _buildFilterSelectorButton(
                icon: LucideIcons.calendarDays,
                label: 'Desde:',
                value: _displayDateFormat.format(startDate),
                onTap: () => _selectDate(context, true),
              ),
              _buildFilterSelectorButton(
                icon: LucideIcons.calendarDays,
                label: 'Hasta:',
                value: _displayDateFormat.format(endDate),
                onTap: () => _selectDate(context, false),
              ),
              _buildFilterSelectorButton(
                icon: LucideIcons.calendar,
                label: 'Año:',
                value: selectedYear?.toString() ?? 'Todos',
                onTap: _showYearPicker,
                onClear:
                    selectedYear != null
                        ? () => setState(() => selectedYear = null)
                        : null,
              ),
              _buildFilterSelectorButton(
                icon: LucideIcons.user,
                label: 'Chofer:',
                value:
                    selectedDriver != null
                        ? '${selectedDriver!.firstName} ${selectedDriver!.lastName}'
                        : 'Todos',
                onTap: () => setState(() => showDrivers = true),
                onClear:
                    selectedDriver != null
                        ? () => setState(() => selectedDriver = null)
                        : null,
              ),
              _buildFilterSelectorButton(
                icon: LucideIcons.userCog,
                label: 'Operador:',
                value:
                    selectedOperator != null
                        ? '${selectedOperator!.first_name} ${selectedOperator!.last_name}'
                        : 'Todos',
                onTap: () => setState(() => showOperators = true),
                onClear:
                    selectedOperator != null
                        ? () => setState(() => selectedOperator = null)
                        : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                icon:
                    loading
                        ? Container(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Icon(LucideIcons.search, size: 18),
                label: Text(loading ? 'Buscando...' : 'Buscar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: loading ? null : () => _fetchTrips(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSelectorButton({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    bool hasValue = value != 'Todos' && value.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColorSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: textColorSecondary),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColorPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasValue && onClear != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onClear,
                child: Icon(
                  LucideIcons.circleX,
                  size: 14,
                  color: errorColor.withOpacity(0.7),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: totalSectionBgColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total General',
                style: TextStyle(fontSize: 13, color: textColorSecondary),
              ),
              Text(
                currencyFormatter.format(totalAmount),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                icon: Icon(LucideIcons.fileText, size: 16),
                label: Text('PDF'),
                onPressed: loading || refreshing ? null : _handleExportPDF,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor.withOpacity(0.5)),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: Icon(LucideIcons.fileSpreadsheet, size: 16),
                label: Text('Excel'),
                onPressed: loading || refreshing ? null : _handleExportExcel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: successColor,
                  side: BorderSide(color: successColor.withOpacity(0.5)),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripsList() {
    if (loading && !refreshing) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }
    if (trips.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () => _fetchTrips(isRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          return _buildTripCard(trips[index]);
        },
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    final driverName =
        trip.driver_profiles != null
            ? '${trip.driver_profiles!['first_name']} ${trip.driver_profiles!['last_name']}'
            : 'No asignado';
    final operatorName =
        trip.operator_profiles != null
            ? '${trip.operator_profiles!['first_name']} ${trip.operator_profiles!['last_name']}'
            : 'No asignado';

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.calendar,
                      size: 14,
                      color: textColorSecondary,
                    ),
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
            const Divider(height: 16, thickness: 0.5),

            _buildDetailRow(
              icon: LucideIcons.mapPin,
              label: 'Origen:',
              value: trip.origin ?? 'N/A',
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              icon: LucideIcons.flag,
              label: 'Destino:',
              value: trip.destination ?? 'N/A',
            ),
            const Divider(height: 16, thickness: 0.5),

            _buildDetailRow(
              icon: LucideIcons.user,
              label: 'Chofer:',
              value: driverName,
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              icon: LucideIcons.userCog,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: textColorSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: textColorSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: textColorPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.fileSearch, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Sin Resultados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No se encontraron viajes que coincidan con los filtros seleccionados.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(LucideIcons.refreshCw, size: 16),
              label: Text('Refrescar'),
              onPressed: () => _fetchTrips(isRefresh: true),
              style: ElevatedButton.styleFrom(
                foregroundColor: primaryColor,
                backgroundColor: primaryColor.withOpacity(0.1),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionModal<T>({
    required String title,
    required List<T> items,
    required List<T> Function(String) filteredItemsBuilder,
    required Widget Function(T) itemBuilder,
    required VoidCallback onClose,
    required VoidCallback onClear,
    required TextEditingController searchController,
    required ValueChanged<String> onSearchChanged,
    required T? selectedItem,
    required String Function(T) itemNameBuilder,
  }) {
    final filteredItems = filteredItemsBuilder(searchController.text);

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
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
                          icon: Icon(LucideIcons.x, color: textColorSecondary),
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
                        contentPadding: EdgeInsets.symmetric(
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
                      'Todos',
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
                  Expanded(
                    child:
                        filteredItems.isEmpty
                            ? Center(
                              child: Text(
                                'No se encontraron coincidencias',
                                style: TextStyle(color: textColorSecondary),
                              ),
                            )
                            : ListView.separated(
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
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await Navigator.of(context).push(
      MaterialPageRoute<DateTime>(
        builder: (BuildContext context) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: primaryColor,
                onPrimary: Colors.white,
                onSurface: textColorPrimary,
              ),
            ),
            child: Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: Center(
                    child: DatePickerDialog(
                      initialDate: isStartDate ? startDate : endDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                      initialEntryMode: DatePickerEntryMode.calendar,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
          if (endDate.isBefore(startDate)) {
            endDate = startDate;
          }
        } else {
          endDate = picked;
          if (startDate.isAfter(endDate)) {
            startDate = endDate;
          }
        }
      });
    }
  }

  void _showYearPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar Año'),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 300,
            height: 300,
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: primaryColor,
                  onPrimary: Colors.white,
                  onSurface: textColorPrimary,
                ),
              ),
              child: YearPicker(
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(Duration(days: 365)),
                selectedDate:
                    selectedYear != null
                        ? DateTime(selectedYear!)
                        : DateTime.now(),
                onChanged: (DateTime dateTime) {
                  setState(() {
                    selectedYear = dateTime.year;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  selectedYear = null;
                });
                Navigator.pop(context);
              },
              child: Text(
                'Quitar Año',
                style: TextStyle(color: textColorSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: primaryColor)),
            ),
          ],
        );
      },
    );
  }
}
