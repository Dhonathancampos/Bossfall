extends SceneTree

## Runner de testes sem janela.
##
##     godot --headless --script res://tests/run_tests.gd
##
## Sem addon: a Godot mais este repositório são tudo que é preciso. Cada método
## que começa com `test_` vira um teste e recebe um TestCase.
##
## Uma suite que não compila, ou que não tem nenhum teste, conta como falha.
## Essa regra existe porque o runner já escondeu uma suite quebrada atrás de um
## "0 falhas" — um runner que mente é pior que nenhum.

const SUITES: Array[String] = [
	"res://tests/test_sim_movement.gd",
	"res://tests/test_sim_networking.gd",
	"res://tests/test_sim_stamina_dodge.gd",
	"res://tests/test_sim_sword.gd",
	"res://tests/test_sim_gnasher.gd",
	"res://tests/test_sim_contract.gd",
	"res://tests/test_sim_parts.gd",
	"res://tests/test_sim_elements.gd",
	"res://tests/test_sim_weapons2.gd",
	"res://tests/test_sim_rework.gd",
	"res://tests/test_assets.gd",
]

func _initialize() -> void:
	var total: int = 0
	var failed: int = 0

	for path in SUITES:
		print("\n%s" % path.get_file())
		var suite_script: GDScript = load(path)
		var names := _test_methods(suite_script)
		if names.is_empty():
			print("  ERRO  a suite não compilou, ou não tem nenhum teste")
			failed += 1
			continue

		for method_name in names:
			total += 1
			var suite: Object = _instantiate(suite_script)
			if suite == null:
				print("  ERRO  %s não pôde ser instanciado" % method_name)
				failed += 1
				continue
			var test_case := TestCase.new()
			suite.call(method_name, test_case)
			if test_case.failures.is_empty():
				print("  ok    %s" % method_name)
			else:
				failed += 1
				print("  FALHA %s" % method_name)
				for failure in test_case.failures:
					print("          %s" % failure)

	print("\n%d testes, %d falhas" % [total, failed])
	quit(1 if failed > 0 else 0)


func _test_methods(suite_script: GDScript) -> Array[String]:
	var names: Array[String] = []
	var probe := _instantiate(suite_script)
	if probe == null:
		return names
	for method in probe.get_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	names.sort()
	return names


## Um script que falhou ao compilar continua carregando, mas `new()` nele não
## existe. Por isso a checagem é pelo resultado, não pelo tipo.
func _instantiate(suite_script: GDScript) -> Object:
	if suite_script == null or not suite_script.can_instantiate():
		return null
	var instance: Variant = suite_script.new()
	return instance if instance is Object else null
