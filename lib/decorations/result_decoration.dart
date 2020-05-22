import 'package:flutter/material.dart';

import '../components/attachment_widget.dart';

/// A set of widgets, builders and style to decorate the screen
/// when the user take/record a story and is seeing the result.
class ResultDecoration {
  /// A button that will save the current story in the directory specified by [StoryController.pathToSave].
  ///
  /// If the path is null, the tap will be ignored.
  final Widget save;

  /// A button to send the [Story] to Firebase.
  ///
  /// Provides the function to send story where you can put the selected releases list
  final Widget Function(BuildContext, Function({List<dynamic> selectedReleases})) publish;

  /// A widget to insert attachments to story like text and stickers
  ///
  /// The attachments are wrapped by [MultiGestureWidget] and can be translated, scaled and rotated
  ///
  /// To delete a specific attachment, pass a list of attachments without the [AttachmentWidget]
  /// you want to delete.
  final Widget Function(BuildContext, Function(List<AttachmentWidget>)) addAttachments;

  ResultDecoration({
    this.save,
    this.publish,
    this.addAttachments,
  });
}
