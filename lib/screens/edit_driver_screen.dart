import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para InputFormatters si se usan
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import '../services/api.dart';

class EditDriverScreen extends StatefulWidget {
  final DriverProfile? driver;

  const EditDriverScreen({Key? key, this.driver}) : super(key: key);

  @override
  _EditDriverScreenState createState() => _EditDriverScreenState();
}

class _EditDriverScreenState extends State<EditDriverScreen> {
  bool loading = false;
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController phoneNumberController;
  late TextEditingController vehicleController;
  late TextEditingController pinController;

  // Variables para los valores del formulario
  late String vehicleType;
  late bool isSpecial;

  // Define colores para consistencia
  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor =
      Colors.white; // Para fondo de inputs si se usa
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red; // Para icono de AppBar
  final Color inputIconColor = Colors.grey.shade500; // Iconos dentro de inputs
  final Color borderColor = Colors.grey.shade300;
  final Color errorColor = Colors.red.shade700;
  final Color successColor = Colors.green.shade600;
  final Color chipSelectedColor = Colors.red.shade50;
  final Color chipSelectedTextColor = Colors.red.shade800;
  final Color chipUnselectedColor = Colors.grey.shade200;
  final Color chipUnselectedTextColor = Colors.grey.shade700;
  // Colores para el botón "Especial"
  final Color specialSelectedBgColor = Colors.amber.shade50;
  final Color specialSelectedBorderColor = Colors.amber.shade600;
  final Color specialSelectedIconColor = Colors.amber.shade700;
  final Color specialSelectedTextColor = Colors.amber.shade800;
  final Color specialUnselectedBgColor = Colors.white;
  final Color specialUnselectedBorderColor = Colors.grey.shade300;
  final Color specialUnselectedIconColor = Colors.grey.shade500;
  final Color specialUnselectedTextColor = Colors.grey.shade700;

  @override
  void initState() {
    super.initState();

    // Inicializar controladores con los valores del conductor
    firstNameController = TextEditingController(
      text: widget.driver?.firstName ?? '',
    );
    lastNameController = TextEditingController(
      text: widget.driver?.lastName ?? '',
    );
    phoneNumberController = TextEditingController(
      text: widget.driver?.phoneNumber ?? '',
    );
    vehicleController = TextEditingController(
      text: widget.driver?.vehicle ?? '',
    );
    pinController = TextEditingController();

    // Inicializar otros valores
    vehicleType = widget.driver?.vehicleType ?? '4_ruedas';
    isSpecial = widget.driver?.isSpecial ?? false;
  }

  @override
  void dispose() {
    // Liberar recursos
    firstNameController.dispose();
    lastNameController.dispose();
    phoneNumberController.dispose();
    vehicleController.dispose();
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
          'vehicle': vehicleController.text,
          'vehicle_type': vehicleType,
          'is_special': isSpecial,
        };

        // Añadir PIN solo si se ha ingresado uno nuevo
        if (pinController.text.isNotEmpty) {
          formData['pin'] = pinController.text;
        }

        final driverService = DriverService();
        await driverService.updateDriver(widget.driver!.id, formData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chofer actualizado correctamente')),
          );
          Navigator.pop(
            context,
            true,
          ); // Devolver true para indicar actualización exitosa
        }
      } catch (error) {
        developer.log('Error actualizando chofer: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo actualizar el Chofer')),
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
          'Editar Chofer (${widget.driver?.firstName})',
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
          child: ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              // Encabezado
              const Text(
                'Editar Chofer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Modifique los datos del Chofer',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Campo Nombre
              _buildInputLabel('Nombre'),
              _buildInputField(
                controller: firstNameController,
                hintText: 'Ingrese el nombre',
                icon: LucideIcons.user,
                validator:
                    (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'El nombre es obligatorio'
                            : null,
              ),
              const SizedBox(height: 12),

              // Campo Apellidos
              _buildInputLabel('Apellidos'),
              _buildInputField(
                controller: lastNameController,
                hintText: 'Ingrese los apellidos',
                icon: LucideIcons.userCheck,
                validator:
                    (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Los apellidos son obligatorios'
                            : null,
              ),
              const SizedBox(height: 12),

              // Campo Teléfono
              _buildInputLabel('Teléfono'),
              _buildInputField(
                controller: phoneNumberController,
                hintText: 'Ej: 55123456',
                icon: LucideIcons.phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'El teléfono es obligatorio';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Campo Vehículo
              _buildInputLabel('Vehículo (Descripción)'),
              _buildInputField(
                controller: vehicleController,
                hintText: 'Ej: Lada Rojo 2010',
                icon: LucideIcons.car,
                validator:
                    (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'La descripción del vehículo es obligatoria'
                            : null,
              ),
              const SizedBox(height: 12),

              // Campo PIN
              _buildInputLabel('PIN (Dejar vacío para no cambiar)'),
              _buildInputField(
                controller: pinController,
                hintText: 'Nuevo PIN de 4 dígitos',
                icon: LucideIcons.keyRound,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length != 4) {
                    return 'El PIN debe tener 4 dígitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Selector de Tipo de Vehículo
              _buildInputLabel('Tipo de Vehículo'),
              Wrap(
                spacing: 12.0,
                runSpacing: 12.0,
                children: [
                  _buildVehicleTypeChip(
                    icon: LucideIcons.car,
                    label: '4 Ruedas',
                    value: '4_ruedas',
                  ),
                  _buildVehicleTypeChip(
                    icon: LucideIcons.bike,
                    label: '2 Ruedas',
                    value: '2_ruedas',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Opción de Conductor Especial
              _buildInputLabel('Prioridad'),
              _buildSpecialDriverButton(),
              const SizedBox(height: 20),

              // Botón de Actualizar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon:
                      loading
                          ? Container(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                          : Icon(LucideIcons.save, size: 18),
                  label: Text(
                    loading ? 'Actualizando...' : 'Actualizar Chofer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onPressed: loading ? null : _handleUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColorSecondary,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int? maxLength,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: inputIconColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14.0,
          horizontal: 12.0,
        ),
        counterText: '',
      ),
      style: TextStyle(fontSize: 15, color: textColorPrimary),
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      validator: validator,
      inputFormatters: inputFormatters,
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _buildVehicleTypeChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    bool isSelected = vehicleType == value;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: isSelected ? chipSelectedTextColor : chipUnselectedTextColor,
      ),
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? chipSelectedTextColor : chipUnselectedTextColor,
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            vehicleType = value;
          });
        }
      },
      selectedColor: chipSelectedColor,
      backgroundColor: chipUnselectedColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color:
              isSelected
                  ? chipSelectedTextColor.withOpacity(0.3)
                  : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      showCheckmark: false,
    );
  }

  Widget _buildSpecialDriverButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          isSpecial = !isSpecial;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSpecial ? specialSelectedBgColor : specialUnselectedBgColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color:
                isSpecial
                    ? specialSelectedBorderColor
                    : specialUnselectedBorderColor,
            width: isSpecial ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.star,
              size: 20,
              color:
                  isSpecial
                      ? specialSelectedIconColor
                      : specialUnselectedIconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Conductor Prioritario',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color:
                      isSpecial
                          ? specialSelectedTextColor
                          : specialUnselectedTextColor,
                ),
              ),
            ),
            if (isSpecial)
              Icon(
                LucideIcons.check,
                color: specialSelectedIconColor,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
