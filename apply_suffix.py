#!/usr/bin/env python3
"""Apply DIGITALT.TV aspect-ratio suffix naming to ImageSquoosher.
Run at the root of boborgdk/ImageSquoosher, branch feature/macos-avif-support.
"""
from pathlib import Path

def replace_exact(filename, old, new):
    p=Path(filename)
    src=p.read_text(encoding='utf-8')
    if old not in src:
        if new in src:
            print(f'Already updated: {filename}')
            return
        raise SystemExit(f'Expected original source not found: {filename}; no files were changed after this error.')
    if src.count(old)!=1:
        raise SystemExit(f'Expected unique target in {filename}, found {src.count(old)}')
    p.write_text(src.replace(old,new,1),encoding='utf-8')
    print('Updated',filename)

planner='lib/utils/output_name_planner.dart'
old='''  /// 入力名、既存名、サフィックスから上書き対象または空き名を決める。'''
new='''  /// Use output dimensions for DIGITALT.TV naming when the default suffix is selected.
  /// Explicit custom suffixes are left untouched. The tolerance accommodates
  /// integer rounding of resized images (e.g. 1000 x 563 for 16:9).
  static String suffixForDimensions({
    required String suffix,
    required int width,
    required int height,
  }) {
    if (suffix != '_resized' || width <= 0 || height <= 0) {
      return suffix;
    }
    final ratio = width / height;
    if ((ratio - 16 / 9).abs() / (16 / 9) <= 0.005) {
      return '_keyart';
    }
    if ((ratio - 2 / 3).abs() / (2 / 3) <= 0.005) {
      return '_poster';
    }
    return suffix;
  }

  /// 入力名、既存名、サフィックスから上書き対象または空き名を決める。'''
replace_exact(planner,old,new)
controller='lib/services/squoosher_controller.dart'
old='''        final outputPlan = OutputNamePlanner.plan(
          inputPath: inputFile.path,
          existingPaths: {...existingPaths, ...occupiedPaths},
          suffix: request.settings.suffix,
          overwrite: request.settings.overwrite,
        );'''
new='''        final sourceDimensions = queuedImage.sourceDimensions;
        final outputDimensions = sourceDimensions == null
            ? null
            : request.settings.plan(sourceDimensions).output;
        final outputSuffix = outputDimensions == null
            ? request.settings.suffix
            : OutputNamePlanner.suffixForDimensions(
                suffix: request.settings.suffix,
                width: outputDimensions.width,
                height: outputDimensions.height,
              );
        final outputPlan = OutputNamePlanner.plan(
          inputPath: inputFile.path,
          existingPaths: {...existingPaths, ...occupiedPaths},
          suffix: outputSuffix,
          overwrite: request.settings.overwrite,
        );'''
replace_exact(controller,old,new)
old='''      final outputPlan = OutputNamePlanner.plan(
        inputPath: queuedImage.path,
        existingPaths: {...existingPaths, ...plannedPaths},
        suffix: settings.suffix,
        overwrite: settings.overwrite,
      );'''
new='''      final outputDimensions = settings.plan(sourceDimensions).output;
      final outputPlan = OutputNamePlanner.plan(
        inputPath: queuedImage.path,
        existingPaths: {...existingPaths, ...plannedPaths},
        suffix: OutputNamePlanner.suffixForDimensions(
          suffix: settings.suffix,
          width: outputDimensions.width,
          height: outputDimensions.height,
        ),
        overwrite: settings.overwrite,
      );'''
replace_exact(controller,old,new)
# Add tests at top of the test suite, before existing tests.
testfile='test/utils/output_name_planner_test.dart'
old="void main() {\n"
new="""void main() {
  test('default suffix follows output dimensions', () {
    expect(OutputNamePlanner.suffixForDimensions(suffix: '_resized', width: 1200, height: 675), '_keyart');
    expect(OutputNamePlanner.suffixForDimensions(suffix: '_resized', width: 1000, height: 563), '_keyart');
    expect(OutputNamePlanner.suffixForDimensions(suffix: '_resized', width: 600, height: 900), '_poster');
    expect(OutputNamePlanner.suffixForDimensions(suffix: '_resized', width: 1200, height: 800), '_resized');
  });

  test('custom suffix takes precedence over automatic naming', () {
    expect(OutputNamePlanner.suffixForDimensions(suffix: '_manual', width: 1200, height: 675), '_manual');
    expect(OutputNamePlanner.suffixForDimensions(suffix: '', width: 600, height: 900), '');
  });

  test('automatic suffix retains collision protection', () {
    final suffix = OutputNamePlanner.suffixForDimensions(suffix: '_resized', width: 1200, height: 675);
    expect(
      OutputNamePlanner.outputPath(
        inputPath: '/pictures/Beck.avif',
        suffix: suffix,
        existingPaths: const ['/pictures/Beck_keyart.jpg'],
      ),
      '/pictures/Beck_keyart (1).jpg',
    );
  });

"""
replace_exact(testfile,old,new)
print('Patch complete. Run dart format and flutter test before committing.')
