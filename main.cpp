#include<vector>
#include<list>
#include<string>
#include<sstream>
#include<map>
#include<set>
#include<fstream>
#include<algorithm>
#include<iostream>
using namespace std;

extern void cavmain(char *filename);
extern double diffms;
int main (int argc, char* argv[]) 
{
	if(argc!=2)
	{
		cout<<"Usage: ./cav input.singular"<<endl;
		return 1;
	}
	cavmain(argv[1]);
	
	cout<<"Total verification time is: "<<diffms<<" ms."<<endl;

	return 0;
}

