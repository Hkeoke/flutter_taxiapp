import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import '../services/api.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' hide Border;
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart' as flutter;

class GeneralReportsScreen extends StatefulWidget {
  const GeneralReportsScreen({Key? key}) : super(key: key);

  @override
  _GeneralReportsScreenState createState() => _GeneralReportsScreenState();
}

class _GeneralReportsScreenState extends State<GeneralReportsScreen> {
  bool loading = true;
  List<Trip> trips = [];
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();
  bool showFilters = false;
  int? selectedYear;
  DriverProfile? selectedDriver;
  OperatorProfile? selectedOperator;
  List<DriverProfile> drivers = [];
  List<OperatorProfile> operators = [];
  String driverSearchTerm = '';
  String operatorSearchTerm = '';
  bool showDrivers = false;
  bool showOperators = false;
  bool showYearPicker = false;
  double totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadPersons();
    _fetchTrips();
  }

  Future<void> _loadPersons() async {
    try {
      final driverService = DriverService();
      final operatorService = OperatorService();

      final driversData = await driverService.getAllDrivers();
      final operatorsData = await operatorService.getAllOperators();

      setState(() {
        drivers = driversData;
        operators = operatorsData;
      });
    } catch (error) {
      developer.log('Error cargando personas: $error');
    }
  }

  Future<void> _fetchTrips() async {
    try {
      setState(() {
        loading = true;
      });

      final analyticsService = AnalyticsService();

      if (!showFilters &&
          selectedYear == null &&
          selectedDriver == null &&
          selectedOperator == null) {
        final data = await analyticsService.getCompletedTrips();
        setState(() {
          trips = data.map((tripData) => Trip.fromJson(tripData)).toList();
          _calculateTotal();
          loading = false;
        });
        return;
      }

      DateTime queryStartDate = startDate;
      DateTime queryEndDate = endDate;

      if (selectedYear != null) {
        queryStartDate = DateTime(selectedYear!, 1, 1);
        queryEndDate = DateTime(selectedYear!, 12, 31);
      }

      final data = await analyticsService.getCompletedTrips(
        startDate: queryStartDate.toIso8601String(),
        endDate: queryEndDate.toIso8601String(),
        driverId: selectedDriver?.id,
        operatorId: selectedOperator?.id,
      );

      setState(() {
        trips = data.map((tripData) => Trip.fromJson(tripData)).toList();
        _calculateTotal();
        loading = false;
      });
    } catch (error) {
      developer.log('Error al obtener viajes: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar los viajes')),
      );
      setState(() {
        loading = false;
      });
    }
  }

  void _calculateTotal() {
    double total = 0;
    for (var trip in trips) {
      total += trip.price;
    }
    totalAmount = total;
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true; // En iOS no necesitamos estos permisos
  }

  Future<void> _handleExportPDF() async {
    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se necesitan permisos de almacenamiento'),
          ),
        );
        return;
      }

      // Crear PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, child: pw.Text('Reporte de Viajes')),
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey400),
                  ),
                ),
                child: pw.Text(
                  'Total de Viajes: \$${totalAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Table.fromTextArray(
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
                      return [
                        DateFormat(
                          'dd/MM/yyyy',
                        ).format(DateTime.parse(trip.createdAt)),
                        trip.origin,
                        trip.destination,
                        trip.driver_profiles != null
                            ? '${trip.driver_profiles!['first_name']} ${trip.driver_profiles!['last_name']}'
                            : 'No asignado',
                        trip.operator_profiles != null
                            ? '${trip.operator_profiles!['first_name']} ${trip.operator_profiles!['last_name']}'
                            : 'No asignado',
                        '\$${trip.price}',
                      ];
                    }).toList(),
              ),
            ];
          },
        ),
      );

      // Guardar PDF
      final output = await getTemporaryDirectory();
      final fileName =
          'Reporte_Viajes_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Compartir PDF
      await Share.shareXFiles([XFile(file.path)], text: 'Reporte de Viajes');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF generado correctamente')),
      );
    } catch (error) {
      developer.log('Error al generar PDF: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo generar el PDF')),
      );
    }
  }

  Future<void> _handleExportExcel() async {
    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se necesitan permisos de almacenamiento'),
          ),
        );
        return;
      }

      // Crear Excel
      final excel = Excel.createExcel();
      final sheet = excel['Viajes'];

      // Añadir encabezados
      sheet.appendRow([
        TextCellValue('Fecha'),
        TextCellValue('Origen'),
        TextCellValue('Destino'),
        TextCellValue('Chofer'),
        TextCellValue('Operador'),
        TextCellValue('Precio'),
      ]);

      // Añadir datos
      for (var trip in trips) {
        sheet.appendRow([
          TextCellValue(
            DateFormat('dd/MM/yyyy').format(DateTime.parse(trip.createdAt)),
          ),
          TextCellValue(trip.origin),
          TextCellValue(trip.destination),
          TextCellValue(
            trip.driver_profiles != null
                ? '${trip.driver_profiles!['first_name']} ${trip.driver_profiles!['last_name']}'
                : 'No asignado',
          ),
          TextCellValue(
            trip.operator_profiles != null
                ? '${trip.operator_profiles!['first_name']} ${trip.operator_profiles!['last_name']}'
                : 'No asignado',
          ),
          TextCellValue(trip.price.toString()),
        ]);
      }

      // Añadir fila de total
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Total:'),
        TextCellValue(totalAmount.toString()),
      ]);

      // Guardar Excel
      final output = await getTemporaryDirectory();
      final fileName =
          'Reporte_Viajes_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);

      // Compartir Excel
      await Share.shareXFiles([XFile(file.path)], text: 'Reporte de Viajes');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel generado correctamente')),
      );
    } catch (error) {
      developer.log('Error al generar Excel: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo generar el Excel')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes Generales')),
      body: Stack(
        children: [
          Column(
            children: [
              // Filtros
              _buildFiltersSection(),

              // Total
              _buildTotalSection(),

              // Lista de viajes
              Expanded(child: _buildTripsList()),
            ],
          ),

          // Dropdowns condicionales
          if (showDrivers) _buildDriversDropdown(),
          if (showOperators) _buildOperatorsDropdown(),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const flutter.BoxDecoration(
        border: flutter.Border(
          bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      showFilters = !showFilters;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: const flutter.BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      border: flutter.Border(
                        bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.listFilter,
                          size: 20,
                          color: const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Filtros',
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronDown,
                          size: 20,
                          color: const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      LucideIcons.fileText,
                      color: const Color(0xFFDC2626),
                    ),
                    onPressed: _handleExportPDF,
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.fileSpreadsheet,
                      color: const Color(0xFFDC2626),
                    ),
                    onPressed: _handleExportExcel,
                  ),
                ],
              ),
            ],
          ),
          if (showFilters) _buildFiltersPanel(),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: const flutter.BoxDecoration(
        border: flutter.Border(
          bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        children: [
          // Selector de año
          InkWell(
            onTap: () {
              _showYearPicker();
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const flutter.BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.all(Radius.circular(8)),
                border: flutter.Border(
                  bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 20,
                    color: const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedYear?.toString() ?? 'Seleccionar Año',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            selectedYear != null
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  if (selectedYear != null)
                    InkWell(
                      onTap: () {
                        setState(() {
                          selectedYear = null;
                        });
                      },
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Selectores de fecha
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        startDate = date;
                      });
                    }
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: const flutter.BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      border: flutter.Border(
                        bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.calendar,
                          size: 20,
                          color: const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(startDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        endDate = date;
                      });
                    }
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: const flutter.BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      border: flutter.Border(
                        bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.calendar,
                          size: 20,
                          color: const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(endDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selector de chofer
          InkWell(
            onTap: () {
              setState(() {
                showDrivers = !showDrivers;
                showOperators = false;
              });
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const flutter.BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.all(Radius.circular(8)),
                border: flutter.Border(
                  bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.user,
                    size: 20,
                    color: const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedDriver != null
                          ? '${selectedDriver!.firstName} ${selectedDriver!.lastName}'
                          : 'Seleccionar Chofer',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            selectedDriver != null
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  if (selectedDriver != null)
                    InkWell(
                      onTap: () {
                        setState(() {
                          selectedDriver = null;
                        });
                      },
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Selector de operador
          InkWell(
            onTap: () {
              setState(() {
                showOperators = !showOperators;
                showDrivers = false;
              });
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const flutter.BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.all(Radius.circular(8)),
                border: flutter.Border(
                  bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.user,
                    size: 20,
                    color: const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedOperator != null
                          ? '${selectedOperator!.firstName} ${selectedOperator!.lastName}'
                          : 'Seleccionar Operador',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            selectedOperator != null
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  if (selectedOperator != null)
                    InkWell(
                      onTap: () {
                        setState(() {
                          selectedOperator = null;
                        });
                      },
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Botón de búsqueda
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon:
                  loading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFDC2626),
                        ),
                      )
                      : Icon(
                        LucideIcons.search,
                        size: 24,
                        color: const Color(0xFFDC2626),
                      ),
              onPressed: loading ? null : _fetchTrips,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversDropdown() {
    final filteredDrivers =
        driverSearchTerm.isEmpty
            ? drivers
            : drivers.where((driver) {
              final fullName =
                  '${driver.firstName} ${driver.lastName}'.toLowerCase();
              return fullName.contains(driverSearchTerm.toLowerCase());
            }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const flutter.BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
        border: flutter.Border(
          bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar chofer...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: const Color(0xFF94A3B8)),
              ),
              onChanged: (value) {
                setState(() {
                  driverSearchTerm = value;
                });
              },
            ),
          ),
          Container(
            height: 200,
            child: ListView.builder(
              itemCount: filteredDrivers.length,
              itemBuilder: (context, index) {
                final driver = filteredDrivers[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      selectedDriver = driver;
                      showDrivers = false;
                      driverSearchTerm = '';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const flutter.BoxDecoration(
                      border: flutter.Border(
                        bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Text(
                      '${driver.firstName} ${driver.lastName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorsDropdown() {
    final filteredOperators =
        operatorSearchTerm.isEmpty
            ? operators
            : operators.where((operator) {
              final fullName =
                  '${operator.firstName} ${operator.lastName}'.toLowerCase();
              return fullName.contains(operatorSearchTerm.toLowerCase());
            }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const flutter.BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
        border: flutter.Border(
          bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar operador...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: const Color(0xFF94A3B8)),
              ),
              onChanged: (value) {
                setState(() {
                  operatorSearchTerm = value;
                });
              },
            ),
          ),
          Container(
            height: 200,
            child: ListView.builder(
              itemCount: filteredOperators.length,
              itemBuilder: (context, index) {
                final operator = filteredOperators[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      selectedOperator = operator;
                      showOperators = false;
                      operatorSearchTerm = '';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const flutter.BoxDecoration(
                      border: flutter.Border(
                        bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Text(
                      '${operator.firstName} ${operator.lastName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: const flutter.BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.all(Radius.circular(8)),
        border: flutter.Border(
          bottom: flutter.BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total de Viajes:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          Text(
            '\$${totalAmount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsList() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (trips.isEmpty) {
      return Center(
        child: Text(
          'No hay viajes que mostrar',
          style: TextStyle(fontSize: 16, color: const Color(0xFF64748B)),
        ),
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

  Widget _buildTripCard(Trip trip) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del viaje
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat(
                    'dd/MM/yyyy',
                  ).format(DateTime.parse(trip.createdAt)),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFDC2626),
                  ),
                ),
                Text(
                  '\$${trip.price}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Detalles del viaje
            Row(
              children: [
                const Text(
                  'Origen:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.origin,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'Destino:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.destination,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Pie del viaje
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const flutter.BoxDecoration(
                border: flutter.Border(
                  bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Chofer:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip.driver_profiles != null
                              ? '${trip.driver_profiles!['first_name']} ${trip.driver_profiles!['last_name']}'
                              : 'No asignado',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'Operador:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip.operator_profiles != null
                              ? '${trip.operator_profiles!['first_name']} ${trip.operator_profiles!['last_name']}'
                              : 'No asignado',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showYearPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar Año'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(DateTime.now().year - 10, 1),
              lastDate: DateTime(DateTime.now().year + 1, 0),
              selectedDate:
                  selectedYear != null
                      ? DateTime(selectedYear!, 1)
                      : DateTime.now(),
              onChanged: (DateTime dateTime) {
                setState(() {
                  selectedYear = dateTime.year;
                });
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }
}

// Widget para seleccionar fecha
class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime value;
  final Function(DateTime) onChanged;

  const DatePickerField({
    Key? key,
    required this.label,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (picked != null && picked != value) {
          onChanged(picked);
        }
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const flutter.BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.all(Radius.circular(8)),
          border: flutter.Border(
            bottom: flutter.BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.calendar,
              size: 20,
              color: const Color(0xFFDC2626),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd/MM/yyyy').format(value),
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }
}
