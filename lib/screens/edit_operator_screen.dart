import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para InputFormatters
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import '../services/api.dart';

class EditOperatorScreen extends StatefulWidget {
  final OperatorProfile? operator;

  const EditOperatorScreen({Key? key, this.operator}) : super(key: key);

  @override
  _EditOperatorScreenState createState() => _EditOperatorScreenState();
}

class _EditOperatorScreenState extends State<EditOperatorScreen> {
  bool loading = false;
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController phoneNumberController;
  late TextEditingController pinController;

  // Define colores para consistencia (iguales a EditDriverScreen)
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

  @override
  void initState() {
    super.initState();

    // Imprimir la estructura del objeto para depuración
    developer.log('Estructura del operador: ${widget.operator.toString()}');

    // Inicializar controladores con los valores del operador
    firstNameController = TextEditingController(
      text: widget.operator?.first_name ?? '',
    );
    lastNameController = TextEditingController(
      text: widget.operator?.last_name ?? '',
    );

    // Usar acceso directo a las propiedades en snake_case
    phoneNumberController = TextEditingController(
      text: widget.operator?.phone_number ?? '',
    );

    pinController = TextEditingController();

    developer.log('Datos del operador: ${widget.operator?.toJson()}');
  }

  @override
  void dispose() {
    // Liberar recursos
    firstNameController.dispose();
    lastNameController.dispose();
    phoneNumberController.dispose();
    pinController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          loading = true;
        });

        // Preparar datos para actualización
        final Map<String, dynamic> formData = {
          'first_name': firstNameController.text,
          'last_name': lastNameController.text,
          'phone_number': phoneNumberController.text,
        };

        // Añadir PIN solo si se ha ingresado uno nuevo
        if (pinController.text.isNotEmpty) {
          formData['pin'] = pinController.text;
        }

        final operatorService = OperatorService();
        await operatorService.updateOperator(widget.operator!.id, formData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Operador actualizado correctamente')),
          );
          Navigator.pop(
            context,
            true,
          ); // Devolver true para indicar actualización exitosa
        }
      } catch (error) {
        developer.log('Error actualizando operador: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo actualizar el Operador')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Editar Operador (${widget.operator?.first_name})',
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                const Text(
                  'Editar Operador',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Modifique los datos del Operador',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),

                // Campo Nombre
                _buildInputLabel('Nombre', true),
                _buildInputField(
                  controller: firstNameController,
                  icon: LucideIcons.user,
                  hintText: 'Ingrese el nombre',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Campo Apellidos
                _buildInputLabel('Apellidos', true),
                _buildInputField(
                  controller: lastNameController,
                  icon: LucideIcons.user,
                  hintText: 'Ingrese los apellidos',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese los apellidos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Campo Teléfono
                _buildInputLabel('Teléfono', true),
                _buildInputField(
                  controller: phoneNumberController,
                  icon: LucideIcons.phone,
                  hintText: 'Ingrese el número de teléfono',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el teléfono';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Campo PIN
                _buildInputLabel('PIN', false),
                _buildInputField(
                  controller: pinController,
                  icon: LucideIcons.key,
                  hintText: 'Ingrese nuevo PIN (opcional)',
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                ),
                const SizedBox(height: 20),

                // Botón de actualizar
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: loading ? null : _handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                    ),
                    child:
                        loading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Actualizar Operador',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF334155),
            ),
          ),
          if (required)
            const Text(' *', style: TextStyle(color: Color(0xFFEF4444))),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                counterText: '',
              ),
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              keyboardType: keyboardType,
              obscureText: obscureText,
              maxLength: maxLength,
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }
}
