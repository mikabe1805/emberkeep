// What the daybook can ask of Plans. The room draws; the page owns the
// schedule, so every change goes back through these.
library;

import 'package:flutter/widgets.dart';

import '../../../academic_calendar/data/academic_calendar_preferences.dart'
    show AcademicCalendarMode;
import '../../../academic_calendar/widgets/academic_calendar_sections.dart';
import '../../../daybook/data/daybook_preferences.dart';
import '../../../daybook/services/directions_launcher.dart';
import '../../../models.dart';

class PlansActions {
  const PlansActions({
    required this.onMode,
    required this.onSelectDay,
    required this.onMoveSpan,
    required this.onToday,
    required this.onAdd,
    required this.onPlanQuest,
    required this.onAddClasses,
    required this.onOpenJournal,
    required this.onOpenNotebook,
    required this.onOpenDaybookActions,
    required this.onToggleTask,
    required this.onToggleWork,
    required this.onOpenStudyPlanner,
    required this.onToggleStudyBlock,
    required this.onUpdateTransitionBuffer,
    required this.onOpenOccurrenceAdjuster,
    required this.directionsLauncher,
    required this.daybookPreferences,
    this.onCompleteQuestPlan,
  });

  /// The MONTH / WEEK / DAY / 3 DAYS switch.
  final ValueChanged<AcademicCalendarMode> onMode;

  /// A day was chosen (a tab, a week column, a date in the month).
  final ValueChanged<DateTime> onSelectDay;

  /// Turn the page: one step forward (1) or back (-1) in the view in use: a
  /// day, a week or a month.
  final ValueChanged<int> onMoveSpan;

  /// Back to today.
  final VoidCallback onToday;

  /// ADD: the daybook's add choices (event, task, add your classes, class,
  /// assignment, exam).
  final VoidCallback onAdd;

  /// PLAN QUEST on the selected day.
  final VoidCallback onPlanQuest;

  /// Opens the Add your classes sheet.
  final VoidCallback onAddClasses;

  /// Reads a journal line.
  final ValueChanged<Note> onOpenJournal;

  final OpenAcademicNotebook onOpenNotebook;
  final OpenDaybookActions onOpenDaybookActions;
  final ToggleDaybookTask onToggleTask;
  final ToggleAcademicWork onToggleWork;
  final OpenAcademicStudyPlanner onOpenStudyPlanner;
  final ToggleAcademicStudyBlock onToggleStudyBlock;
  final UpdateAcademicTransitionBuffer onUpdateTransitionBuffer;
  final OpenAcademicOccurrenceAdjuster onOpenOccurrenceAdjuster;
  final DirectionsLauncher directionsLauncher;
  final DaybookPreferences daybookPreferences;
  final CompleteQuestPlan? onCompleteQuestPlan;
}
