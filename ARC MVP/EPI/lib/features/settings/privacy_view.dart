import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/settings/settings_cubit.dart';
import 'package:my_app/features/settings/widgets/settings_tile.dart';

class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsCubit(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Privacy',
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Local Only Mode
                SettingsTile(
                  title: 'Local Only Mode',
                  subtitle: 'Keep all data on this device only',
                  trailing: Switch(
                    value: state.localOnlyMode,
                    onChanged: (value) {
                      context.read<SettingsCubit>().toggleLocalOnlyMode(value);
                    },
                  ),
                ),
                const Divider(color: Colors.grey),
                
                // Biometric Lock
                SettingsTile(
                  title: 'Biometric Lock',
                  subtitle: 'Require biometric authentication to open app',
                  trailing: Switch(
                    value: state.biometricLock,
                    onChanged: (value) {
                      context.read<SettingsCubit>().toggleBiometricLock(value);
                    },
                  ),
                ),
                const Divider(color: Colors.grey),
                
                // Export Data
                SettingsTile(
                  title: 'Export Data',
                  subtitle: 'Allow exporting your data',
                  trailing: Switch(
                    value: state.exportDataEnabled,
                    onChanged: (value) {
                      context.read<SettingsCubit>().toggleExportData(value);
                    },
                  ),
                ),
                const Divider(color: Colors.grey),
                
                // Delete All Data
                SettingsTile(
                  title: 'Delete All Data',
                  subtitle: 'Allow deleting all your data',
                  trailing: Switch(
                    value: state.deleteDataEnabled,
                    onChanged: (value) {
                      context.read<SettingsCubit>().toggleDeleteData(value);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
