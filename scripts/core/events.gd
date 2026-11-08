extends Node
## Шина подій (автозавантаження «Events»).
## Системи повідомляють, що сталося, не знаючи, хто на це реагує:
## вороги не викликають менеджер гри напряму, а лише випромінюють подію.

# Бій
signal enemy_killed(enemy: Node2D)
signal boss_spawned(enemy: Node2D)
signal player_hurt
signal player_died
signal level_up(level: int)
signal companion_down(index: int, name: String)
signal item_found(item: Dictionary)

# Локації
signal field_cleared(loc_id: String)
signal dungeon_cleared(loc_id: String)
signal exit_requested  # гравець зайшов у портал виходу

# Повідомлення для інтерфейсу
signal banner(text: String, color: Color)
signal hint(id: String, text: String)
