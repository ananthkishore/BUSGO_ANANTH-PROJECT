class BusGoBreakpoints {
  const BusGoBreakpoints._();

  static const double compact = 600;
  static const double wideContent = 1024;

  static bool isCompact(double width) => width < compact;

  static double maxContentWidth(double width) =>
      width < wideContent ? 960 : 1400;
}
