extends TestCase
## Hoot autoload: tip queue, priorities, once-keys, mastery, anchors.

var shown: Array = []
var dismissed: Array = []


func before_each() -> void:
	Hoot.clear()
	Hoot.reset_visit()
	shown.clear()
	dismissed.clear()
	Events.hoot_tip_shown.connect(_on_shown)
	Events.hoot_tip_dismissed.connect(_on_dismissed)


func after_each() -> void:
	Events.hoot_tip_shown.disconnect(_on_shown)
	Events.hoot_tip_dismissed.disconnect(_on_dismissed)
	Hoot.clear()


func _on_shown(tip: Dictionary) -> void:
	shown.append(tip)


func _on_dismissed(id: int) -> void:
	dismissed.append(id)


func test_one_tip_at_a_time_in_priority_order() -> void:
	Hoot.say("first", Hoot.NORMAL)
	Hoot.say("low one", Hoot.LOW)
	Hoot.say("high one", Hoot.HIGH)
	assert_eq(shown.size(), 1)
	assert_eq(shown[0]["text"], "first")
	Hoot.dismiss_current()
	assert_eq(shown[-1]["text"], "high one", "higher priority goes next")
	Hoot.dismiss_current()
	assert_eq(shown[-1]["text"], "low one")


func test_urgent_interrupts() -> void:
	Hoot.say("chatty", Hoot.NORMAL)
	Hoot.say("STOP", Hoot.URGENT)
	assert_eq(shown[-1]["text"], "STOP")
	assert_eq(dismissed.size(), 1)


func test_say_once_per_visit() -> void:
	assert_true(Hoot.say_once("k", "hello"))
	assert_false(Hoot.say_once("k", "hello again"))
	Hoot.reset_visit()
	assert_true(Hoot.say_once("k", "hello after reset"))


func test_signal_path() -> void:
	Events.hoot_say.emit("via signal", Hoot.NORMAL, "")
	assert_eq(shown.size(), 1)
	assert_eq(shown[0]["text"], "via signal")


func test_auto_timeout() -> void:
	Hoot.say("short", Hoot.NORMAL, "", "", 0.2)
	await wait_seconds(0.4)
	assert_false(Hoot.is_showing(), "tip timed out")


func test_word_limit_warns() -> void:
	allow_errors()
	var id := Hoot.say("one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen")
	assert_true(id > 0, "still shown, only warned")


func test_mastery() -> void:
	var skill := &"test_skill_%d" % randi()
	assert_false(Hoot.is_mastered(skill))
	for i in Hoot.MASTERY_CLEAN_USES:
		Hoot.note_clean_use(skill)
	assert_true(Hoot.is_mastered(skill))
	assert_eq(Hoot.say("tip", Hoot.NORMAL, "", "", -1.0, skill), -1, "mastered skills stay quiet")
	(Game.progress["hoot_mastery"] as Dictionary).erase(String(skill))


func test_anchor_rect() -> void:
	var c := Control.new()
	c.position = Vector2(100, 50)
	c.size = Vector2(40, 20)
	add_node(c)
	Hoot.register_anchor("test_anchor", c)
	var r := Hoot.anchor_screen_rect("test_anchor")
	assert_eq(r.position, Vector2(100, 50))
	assert_eq(r.size, Vector2(40, 20))
	assert_true(Hoot.has_anchor("test_anchor"))
	Hoot.unregister_anchor("test_anchor")
	assert_false(Hoot.has_anchor("test_anchor"))
