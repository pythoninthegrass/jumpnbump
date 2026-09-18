extends GdUnitTestSuite

## Asserts the JumpnbumpWorld GDExtension class actually loaded (TASK-014.07).
## A silently-unloaded GDExtension would otherwise make every other test
## that touches SimWorld fail with an unrelated "class not found" error, so
## this exists to fail loudly and specifically, right here, instead of
## hiding behind some other test.


func test_jumpnbump_world_class_is_registered() -> void:
	assert_bool(ClassDB.class_exists("JumpnbumpWorld")).is_true()
