fun test(m: Map<Int, Int>) = m.getOrDefault(1, 2)

fun test2(s: String) = s.length

fun remove(l: MutableList<Int>) {
    l.remove(5)
}

fun fn1(s: String) = s.plus(other = "")
fun fn2(s: String) = s + ""

fun fn1(i: Int) = i.minus(10)
fun fn2(i: Int) = i - 10
