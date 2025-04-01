import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart'; // Para formatear moneda
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import '../widgets/sidebar.dart'; // Asegúrate que este widget esté estilizado

class AdminDriverBalances extends StatefulWidget {
  const AdminDriverBalances({Key? key}) : super(key: key);

  @override
  _AdminDriverBalancesState createState() => _AdminDriverBalancesState();
}

class _AdminDriverBalancesState extends State<AdminDriverBalances> {
  bool isSidebarVisible = false;
  List<DriverProfile> drivers = [];
  bool loading = true;
  bool _isUpdatingBalance = false; // Para el estado de carga del modal
  String searchQuery = '';
  DriverProfile? selectedDriver;
  final _amountController = TextEditingController(); // Controller para el monto
  final _descriptionController =
      TextEditingController(); // Controller para la descripción
  bool modalVisible = false;
  BalanceOperationType operationType = BalanceOperationType.recarga;

  // Define colores para consistencia (puedes moverlos a un archivo de constantes)
  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color successColor = Colors.green.shade600;
  final Color errorColor = Colors.red.shade700;
  final Color buttonTextColor = Colors.white;

  // Formateador de moneda
  final currencyFormatter = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  @override
  void initState() {
    super.initState();
    loadDrivers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadDrivers({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        loading = true;
      });
    }
    try {
      final driverService = DriverService();
      final driversData = await driverService.getAllDrivers();
      if (mounted) {
        setState(() {
          drivers = driversData;
          loading = false;
        });
      }
    } catch (error) {
      developer.log('Error cargando conductores: $error');
      if (mounted) {
        setState(() {
          loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron cargar los conductores: $error'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> handleBalanceUpdate() async {
    if (selectedDriver == null ||
        _amountController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor complete todos los campos'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final amountValue = double.tryParse(_amountController.text);
    if (amountValue == null || amountValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor ingrese un monto válido'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error de autenticación'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    setState(() => _isUpdatingBalance = true); // Iniciar carga en modal

    try {
      final driverService = DriverService();
      await driverService.updateDriverBalance(
        selectedDriver!.id,
        amountValue,
        operationType,
        _descriptionController.text,
        authProvider.user!.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Balance actualizado correctamente'),
            backgroundColor: successColor,
          ),
        );
        setState(() {
          modalVisible = false;
          _amountController.clear();
          _descriptionController.clear();
          selectedDriver = null; // Deseleccionar conductor
        });
        await loadDrivers(
          showLoading: false,
        ); // Recargar lista sin mostrar loading general
      }
    } catch (error) {
      developer.log('Error actualizando balance: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo actualizar el balance: $error'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingBalance = false); // Detener carga en modal
      }
    }
  }

  List<DriverProfile> get filteredDrivers {
    if (searchQuery.isEmpty) {
      return drivers;
    }
    return drivers.where((driver) {
      final fullName = '${driver.firstName} ${driver.lastName}'.toLowerCase();
      final query = searchQuery.toLowerCase();
      return fullName.contains(query);
    }).toList();
  }

  void _showBalanceModal(DriverProfile driver, BalanceOperationType type) {
    if (mounted) {
      setState(() {
        selectedDriver = driver;
        operationType = type;
        modalVisible = true;
        _amountController.clear();
        _descriptionController.clear();
      });
    }
  }

  void _hideBalanceModal() {
    if (mounted) {
      setState(() {
        modalVisible = false;
        _isUpdatingBalance = false; // Asegurarse de resetear el estado de carga
        _amountController.clear();
        _descriptionController.clear();
        selectedDriver = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        title: const Text(
          'Gestión de Balances',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.menu, color: iconColor),
          onPressed: () => setState(() => isSidebarVisible = true),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSearchBar(), // Barra de búsqueda estilizada
              Expanded(
                child:
                    loading
                        ? Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        )
                        : _buildDriverList(), // Lista de conductores
              ),
            ],
          ),

          // Modal para actualizar balance
          if (modalVisible) _buildBalanceModal(),

          // Sidebar
          if (isSidebarVisible)
            Sidebar(
              isVisible: isSidebarVisible,
              onClose: () => setState(() => isSidebarVisible = false),
              role: 'admin',
            ),
        ],
      ),
    );
  }

  // Widget para la barra de búsqueda
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Buscar por nombre...',
          hintStyle: TextStyle(color: textColorSecondary),
          prefixIcon: Icon(Icons.search, color: textColorSecondary),
          filled: true,
          fillColor: cardBackgroundColor,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10.0,
            horizontal: 15.0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
        ),
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
      ),
    );
  }

  // Widget para la lista de conductores
  Widget _buildDriverList() {
    if (filteredDrivers.isEmpty && !loading) {
      return Center(
        child: Text(
          searchQuery.isEmpty
              ? 'No hay conductores registrados.'
              : 'No se encontraron conductores.',
          style: TextStyle(color: textColorSecondary, fontSize: 16),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => loadDrivers(showLoading: false),
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16,
        ), // Ajustar padding
        itemCount: filteredDrivers.length,
        itemBuilder: (context, index) {
          final driver = filteredDrivers[index];
          return _buildDriverCard(driver); // Usar widget de tarjeta
        },
      ),
    );
  }

  // Widget para la tarjeta de cada conductor
  Widget _buildDriverCard(DriverProfile driver) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2.0,
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${driver.firstName} ${driver.lastName}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textColorPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              // Usar formateador de moneda
              'Balance: ${currencyFormatter.format(driver.balance)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: driver.balance >= 0 ? successColor : errorColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Recargar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successColor,
                      foregroundColor: buttonTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed:
                        () => _showBalanceModal(
                          driver,
                          BalanceOperationType.recarga,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('Descontar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: errorColor,
                      foregroundColor: buttonTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed:
                        () => _showBalanceModal(
                          driver,
                          BalanceOperationType.descuento,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget para el modal de actualización de balance
  Widget _buildBalanceModal() {
    final title =
        operationType == BalanceOperationType.recarga
            ? 'Recargar Balance'
            : 'Descontar Balance';
    final confirmButtonColor =
        operationType == BalanceOperationType.recarga
            ? successColor
            : errorColor;

    return GestureDetector(
      // Permite cerrar el modal tocando fuera
      onTap: _hideBalanceModal,
      child: Container(
        color: Colors.black.withOpacity(0.6), // Overlay más oscuro
        child: Center(
          child: Material(
            // Necesario para evitar que el GestureDetector capture taps dentro del modal
            color: Colors.transparent,
            child: GestureDetector(
              // Evita que el tap dentro del modal lo cierre
              onTap: () {}, // No hacer nada al tocar dentro
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(20), // Padding ajustado
                decoration: BoxDecoration(
                  color: cardBackgroundColor,
                  borderRadius: BorderRadius.circular(
                    16,
                  ), // Bordes más redondeados
                ),
                child: SingleChildScrollView(
                  // Para evitar overflow si el teclado aparece
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18, // Tamaño ajustado
                          fontWeight: FontWeight.w600,
                          color: textColorPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${selectedDriver?.firstName} ${selectedDriver?.lastName}',
                        style: TextStyle(
                          fontSize: 15, // Tamaño ajustado
                          color: textColorSecondary,
                        ),
                      ),
                      const Divider(height: 24), // Divisor visual
                      // Campo de monto
                      TextField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Monto (\$)',
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: textColorSecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        // onChanged no es necesario si usamos controller
                      ),
                      const SizedBox(height: 16),

                      // Campo de descripción
                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Descripción',
                          prefixIcon: Icon(
                            Icons.description_outlined,
                            color: textColorSecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        maxLines: 2, // Límite de líneas
                        textCapitalization: TextCapitalization.sentences,
                        // onChanged no es necesario si usamos controller
                      ),
                      const SizedBox(height: 24),

                      // Botones de acción
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed:
                                _isUpdatingBalance
                                    ? null
                                    : _hideBalanceModal, // Deshabilitar si está cargando
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: textColorSecondary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: confirmButtonColor,
                              foregroundColor: buttonTextColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed:
                                _isUpdatingBalance
                                    ? null
                                    : handleBalanceUpdate, // Deshabilitar si está cargando
                            child:
                                _isUpdatingBalance
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text('Confirmar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
