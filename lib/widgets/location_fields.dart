import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/geo_data.dart';

/// Renders Country (autocomplete) + State (autocomplete, depends on country)
/// + Postal Code in a compact block. Keeps the provided controllers in sync.
class LocationFields extends StatefulWidget {
  final TextEditingController countryCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController postalCtrl;

  const LocationFields({
    super.key,
    required this.countryCtrl,
    required this.stateCtrl,
    required this.postalCtrl,
  });

  @override
  State<LocationFields> createState() => _LocationFieldsState();
}

class _LocationFieldsState extends State<LocationFields> {
  // Tracks which country is active so the state list updates reactively.
  late String _country;

  @override
  void initState() {
    super.initState();
    _country = widget.countryCtrl.text;
  }

  void _onCountrySelected(String value) {
    widget.countryCtrl.text = value;
    widget.stateCtrl.clear();
    setState(() => _country = value);
  }

  @override
  Widget build(BuildContext context) {
    final states = GeoData.statesFor(_country);

    return Column(
      children: [
        // Country
        _GeoAutocomplete(
          label: 'Country',
          controller: widget.countryCtrl,
          options: GeoData.countries,
          onSelected: _onCountrySelected,
        ),
        const SizedBox(height: 12),
        // State + Postal Code
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              // ValueKey forces the widget to fully recreate whenever the
            // country changes, so Autocomplete's internal text resets too.
            child: states.isNotEmpty
                  ? _GeoAutocomplete(
                      key: ValueKey(_country),
                      label: 'State / Province',
                      controller: widget.stateCtrl,
                      options: states,
                      onSelected: (v) => widget.stateCtrl.text = v,
                    )
                  : TextFormField(
                      key: ValueKey(_country),
                      controller: widget.stateCtrl,
                      decoration: const InputDecoration(
                          labelText: 'State / Province'),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: widget.postalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Postal Code'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GeoAutocomplete extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final List<String> options;
  final ValueChanged<String> onSelected;

  // ignore: prefer_const_constructors_in_immutables
  _GeoAutocomplete({
    super.key,
    required this.label,
    required this.controller,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_GeoAutocomplete> createState() => _GeoAutocompleteState();
}

class _GeoAutocompleteState extends State<_GeoAutocomplete> {
  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.controller.text),
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text.toLowerCase();
        if (q.isEmpty) return widget.options;
        // starts-with matches come first, then contains matches
        final starts =
            widget.options.where((o) => o.toLowerCase().startsWith(q));
        final contains = widget.options.where(
            (o) => o.toLowerCase().contains(q) && !o.toLowerCase().startsWith(q));
        return [...starts, ...contains];
      },
      onSelected: (value) {
        widget.controller.text = value;
        widget.onSelected(value);
      },
      fieldViewBuilder: (context, autoCtrl, focusNode, onSubmit) {
        return TextFormField(
          controller: autoCtrl,
          focusNode: focusNode,
          onChanged: (v) => widget.controller.text = v,
          onFieldSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: const Icon(Icons.arrow_drop_down, size: 20,
                color: AppTheme.textSecondary),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  final isSelected =
                      option == widget.controller.text;
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Container(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.08)
                          : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
