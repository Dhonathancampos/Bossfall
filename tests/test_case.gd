class_name TestCase
extends RefCounted

## Coletor de falhas de um teste. Um por método de teste.
##
## Não interrompe no primeiro erro: um teste pode relatar várias falhas, o que
## costuma dizer mais sobre o que quebrou do que a primeira sozinha.

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s — esperado %s, veio %s" % [message, str(expected), str(actual)])

func check_approx(actual: float, expected: float, message: String, epsilon: float = 0.01) -> void:
	if absf(actual - expected) > epsilon:
		failures.append("%s — esperado ~%s, veio %s" % [message, str(expected), str(actual)])

func check_vec_approx(actual: Vector2, expected: Vector2, message: String, epsilon: float = 0.01) -> void:
	if actual.distance_to(expected) > epsilon:
		failures.append("%s — esperado ~%s, veio %s" % [message, str(expected), str(actual)])
