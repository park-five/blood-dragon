set -e
file="$(realpath "$0")"
directory="$(dirname "$file")"
name="$(basename "$directory")"
mkdir -p "$directory/build"
as "$directory/source.asm" -o "$directory/build/$name.o"
ld.lld -z noexecstack --entry stack "$directory/build/$name.o" -o "$directory/build/$name"
llvm-objdump --disassemble --section=.data --section=.rodata --section=.text "$directory/build/$name"
(
	set +e
	echo
	echo "output:"
	"$directory/build/$name" "$@"
	exit="$?"
	if [ "$exit" -ne 0 ]; then
		echo "exit: $exit"
	fi
)
