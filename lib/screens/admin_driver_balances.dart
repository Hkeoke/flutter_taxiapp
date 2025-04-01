import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import '../widgets/sidebar.dart';

class AdminDriverBalances extends StatefulWidget {
  const AdminDriverBalances({Key? key}) : super(key: key);

  @override
  _AdminDriverBalancesState createState() => _AdminDriverBalancesState();
}

class _AdminDriverBalancesState extends State<AdminDriverBalances> {
  bool isSidebarVisible = false;
  List<DriverProfile> drivers = [];
  bool loading = true;
  String searchQuery = '';
  DriverProfile? selectedDriver;
  String amount = '';
  String description = '';
  bool modalVisible = false;
  BalanceOperationType operationType = BalanceOperationType.recarga;

  @override
  void initState() {
    super.initState();
    loadDrivers();
  }

  Future<void> loadDrivers() async {
    try {
      final driverService = DriverService();
      final driversData = await driverService.getAllDrivers();
      setState(() {
        drivers = driversData;
        loading = false;
      });
    } catch (error) {
      developer.log('Error cargando conductores: $error');
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar los conductores')),
      );
    }
  }

  Future<void> handleBalanceUpdate() async {
    if (selectedDriver == null || amount.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor complete todos los campos')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error de autenticación')));
      return;
    }

    try {
      final driverService = DriverService();
      await driverService.updateDriverBalance(
        selectedDriver!.id,
        double.parse(amount),
        operationType,
        description,
        authProvider.user!.id,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balance actualizado correctamente')),
      );
      setState(() {
        modalVisible = false;
        amount = '';
        description = '';
      });
      loadDrivers(); // Recargar la lista para mostrar el nuevo balance
    } catch (error) {
      developer.log('Error actualizando balance: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el balance')),
      );
    }
  }

  List<DriverProfile> get filteredDrivers {
    return drivers.where((driver) {
      final fullName = '${driver.firstName} ${driver.lastName}'.toLowerCase();
      return fullName.contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gestión de Balances'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => setState(() => isSidebarVisible = true),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Balances'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => setState(() => isSidebarVisible = true),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Barra de búsqueda
              Container(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar conductor...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),

              // Lista de conductores
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = filteredDrivers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Información del conductor
                            Text(
                              '${driver.firstName} ${driver.lastName}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Balance: \$${driver.balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Botones de acción
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        selectedDriver = driver;
                                        operationType =
                                            BalanceOperationType.recarga;
                                        modalVisible = true;
                                      });
                                    },
                                    child: const Text('Recargar'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        selectedDriver = driver;
                                        operationType =
                                            BalanceOperationType.descuento;
                                        modalVisible = true;
                                      });
                                    },
                                    child: const Text('Descontar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Modal para actualizar balance
          if (modalVisible)
            Container(
              color: Colors.black.withOpacity(0.5),
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        operationType == BalanceOperationType.recarga
                            ? 'Recargar Balance'
                            : 'Descontar Balance',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${selectedDriver?.firstName} ${selectedDriver?.lastName}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Campo de monto
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Monto',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            amount = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Campo de descripción
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Descripción',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 3,
                        onChanged: (value) {
                          setState(() {
                            description = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Botones de acción
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                modalVisible = false;
                                amount = '';
                                description = '';
                              });
                            },
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0891B2),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: handleBalanceUpdate,
                            child: const Text('Confirmar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

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
}
