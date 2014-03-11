cav: main.cpp scanner.cpp parser.cpp 
	g++ scanner.cpp parser.cpp main.cpp -O3 -g -o cav
	sleep 2
#	while [ $$? != 0 ] ; do echo "no differences"; done
#.y file is first compiled.
parser.cpp:CAV.y
	bison -p cav -d CAV.y -o parser.cpp 
scanner.cpp:CAV.l
	flex -o scanner.cpp -Pcav CAV.l
clean:
	rm scanner.cpp parser.cpp cav parser.hpp
