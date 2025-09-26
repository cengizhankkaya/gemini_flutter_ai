class StoryCharacter {
  final String name;
  final String description;
  final String personality;
  final String background;

  const StoryCharacter({
    required this.name,
    required this.description,
    required this.personality,
    required this.background,
  });
}

class StorySetting {
  final String location;
  final String time;
  final String atmosphere;
  final String description;

  const StorySetting({
    required this.location,
    required this.time,
    required this.atmosphere,
    required this.description,
  });
}

class StoryEvent {
  final String title;
  final String description;
  final String conflict;
  final String resolution;

  const StoryEvent({
    required this.title,
    required this.description,
    required this.conflict,
    required this.resolution,
  });
}

class GeneratedStory {
  final String title;
  final String content;
  final StoryCharacter character;
  final StorySetting setting;
  final StoryEvent event;
  final DateTime createdAt;

  const GeneratedStory({
    required this.title,
    required this.content,
    required this.character,
    required this.setting,
    required this.event,
    required this.createdAt,
  });
}

class StorySelections {
  final StoryCharacter character;
  final StorySetting setting;
  final StoryEvent event;

  const StorySelections({
    required this.character,
    required this.setting,
    required this.event,
  });
}


