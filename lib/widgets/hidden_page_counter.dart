import 'package:flutter/material.dart';
import 'package:flureadium/flureadium.dart';

class HiddenPageCounter
    extends StatelessWidget {

  final Publication
      publication;

  const HiddenPageCounter({
    super.key,
    required
        this.publication,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Positioned(
      left: -9999,
      top: -9999,
      child: SizedBox(
        width: 1,
        height: 1,
        child:
            IgnorePointer(
          child:
              ReadiumReaderWidget(
            publication:
                publication,

            onReady:
                () {
              debugPrint(
                'HIDDEN READER READY',
              );
            },
          ),
        ),
      ),
    );
  }
}