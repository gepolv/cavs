/***************************************************************************

  FileName    [OGBC.y]

  PackageName [MVD: Multi-Variable Division]

  Synopsis    [Syntax analyzer for EQN format.]

  Author      [Jinpeng Lv]
******************************************************************************/
%{
#include<cstdio>
#include<cstdlib>
#include<iostream>
#include<map>
#include<list>
#include<set>
#include<vector>
#include<string>
#include<cstring>
#include<fstream>
#include<cassert>
#include<algorithm>
//#include "cav.hpp"
using namespace std;

/*************Definition of Flex&Bison**********/
extern int cavlineno;
extern FILE *cavin;
extern FILE *cavout;
int caverror(const char *s);
extern int cavlex();

double diffms(0.0);
static clock_t end;
static clock_t begin;
/**********************************************/
/**********************************************/
typedef set<unsigned int> monomial;
static monomial tempmon;

static list<monomial> glopoly;
static list<monomial> specpoly;

static vector< list<monomial> > ideal;

static map<string, unsigned int> VID;   // mapping:  variable -> ID
static map<unsigned int,string> DIV;   // mapping:  ID --> variable  
static unsigned int ind=2;				//ID index. "0" is not supposed to occur in any monomial.

static map<string, unsigned int>::iterator mapit;


static void HandleMiter(string out1, string out2);
static int CompareSet(set<unsigned int> &set1,set<unsigned int> &set2);

/*sorting monomials when inserting into polynomial*/
static void insertmon(monomial & tempmon);
/*merge sort of two sorted polys*/
void mergesort(list<monomial>& specpoly,list<monomial>& tempoly);
/*insertion order, insert tempmon into poly*/
static void insertmon2poly(list<monomial>& poly, monomial & mon);

/***  kernel function***/
/*multivariate polynomial reduction*/
static void reduce(list<monomial> & specpoly,vector< list<monomial> > &ideal );
static void HandleVar(char * var);

static void clear();

/**********aux functions*******/
static void printmap();
static void printmonomial(monomial & toprint);
static void printpoly(list<monomial> &toprint);
static void printideal(vector< list<monomial> > &toprint);

static int digione; //the corresponding index of number 1.

%}

/* variable returned by lex */
%union
{
  char* id; 
};

/* definition of token */

%token <id> VARIABLE

%left '+' 
%left '*' 
%left '^' 


%type <id> poly polys var gmonomial


%%
statements:statement	{reduce(specpoly,ideal);clear();}
	| statements statement {reduce(specpoly,ideal);clear();}
	;
statement:
	vardelc ';' miterpoly ';' polys ';'
	;
	
vardelc: var {VID[$1]=ind;DIV[ind]=$1;if(strcmp($1,"1")==0) digione=ind;++ind;  free($1);}
	| vardelc ',' var  {VID[$3]=ind;DIV[ind]=$3;if(strcmp($3,"1")==0) digione=ind;++ind;  free($3);}
	;
	

miterpoly:  var '+' var {HandleMiter($1,$3);free($1);free($3);}
	;
	
polys:poly					{ideal.push_back(glopoly);glopoly.clear();}
	| polys ',' poly		{ideal.push_back(glopoly);glopoly.clear();}
	 ;
	 
poly:	gmonomial		{insertmon(tempmon);tempmon.clear();}//left var of equation
	|	poly '+' gmonomial   {insertmon(tempmon);tempmon.clear();}
	;	
	
gmonomial: var 						{HandleVar($1);free($1);}
	|	gmonomial '*' var			{HandleVar($3);free($3);}
	;
 
var: VARIABLE 
	{
		$$ =strdup($1); //cout<<($$)<<endl;
	}



%%

int caverror(const char *s)
{
cout<<"ERROR:line "<<cavlineno<<": "<<s<<"\n";
return 1;
}

void cavmain(char *filename)
{
	
	cavin=fopen(filename,"r");
	if(!cavin)
	{
		cout<<"Fail to locate file: "<<filename<<endl;
		return;
	}
	cavparse();
	fclose(cavin);
	//printmap();
	//cout<<"Total verification time is: "<<diffms<<" ms."<<endl;
	//cout<<"specpoly:"<<endl;
	//printpoly(specpoly);
	//cout<<"ideal:"<<endl;
	//printideal(ideal);
	
	//cout<<"reduction:"<<endl;
	
	
	//reduce(specpoly,ideal);
	
}

void HandleVar(char * var)
{
	if(VID.find(var)!=VID.end()) 
		tempmon.insert(VID[var]);
	else
	{
		cout<<var<<" undefined\n";
		exit(1);
	}
}


void HandleMiter(string out1,  string out2)
{
	tempmon.insert(VID[out1]);
	specpoly.push_back(tempmon);
	tempmon.clear();
	tempmon.insert(VID[out2]);
	specpoly.push_back(tempmon);
	tempmon.clear();
}

//1 if set1> set2, example: <5,2,3> > <2,3,4>
//0 if set1=set2
//-1 if set1<set2
int CompareSet(monomial &set1,monomial &set2)
{
	set<unsigned int>::iterator it1;
	set<unsigned int>::iterator it2;
	
	for(it1=set1.begin(),it2=set2.begin();((it1!=set1.end()) && (it2!=set2.end()));++it1,++it2)
	if((*it1)>(*it2)) return 1;
	else if((*it1)<(*it2)) return -1;
	
	if(set1.size()>set2.size())
	return -1;
	else if(set1.size()<set2.size())
	return 1;
	else return 0;
}


/*sorting monomials when inserting into polynomial*/
void insertmon(monomial & tempmon)
{
	set<unsigned int>::iterator monit=tempmon.end();
		--monit;
	if ( (*monit==digione) &&  (tempmon.size()>1) )//handle the case: a*b*1
		tempmon.erase(monit);
		
	if(glopoly.size()==0)
	glopoly.push_back(tempmon);
	else
	{
		//sorting first
		list<monomial>::iterator it; //about 5 times faster than reverse iterator.
		it=glopoly.end();
		int temp;
		--it;
	//cout<<"it=";printmonomial(*it);cout<<endl;
		while(it!=glopoly.begin())
		{
			temp=CompareSet(tempmon,*it);//cout<<"compare result is: "<<temp<<endl;
			if( temp==1)//temp > it
			{
				glopoly.insert(++it,tempmon);
		//		cout<<"insert: ";printmonomial(tempmon);//cout<<" into: ";printpoly(glopoly);
				return;
			}
			else if(temp==-1)
			--it;
			else if (temp==0) //same, delete
			{
				glopoly.erase(it);
		//		cout<<"insert: ";printmonomial(tempmon);cout<<" into: ";printpoly(glopoly);
				return;
			}
			
		}
	
		temp=CompareSet(tempmon,*it);//cout<<"compare result is: "<<temp<<endl;
		if( temp==1)//temp > it
		{
			glopoly.insert(++it,tempmon);
		}
		else if(temp==-1)
			glopoly.push_front(tempmon);
		else if (temp==0) //same, delete
		{
			glopoly.erase(it);
		}
	}
	//cout<<"insert: ";printmonomial(tempmon);cout<<" into: ";printpoly(glopoly);
}

/*
Purpose: r = specpoly / ideal 
specpoly is a given polynomial (or called specification polynomial)
ideal is a set of polynomials containing f1,f2,f3,...fn
------------------------------------------------------------
Basic procedure is:
1: get the leading monomials of specpoly, example: f=ab+ac+bc+d; lms(f)=ab+ac, not just "ab"!!! Differnt from traditional method.
2: get the leading monomial of f_i, because the property of circuit, leading monomial of f_i can only be single variable 
3: if the 1st variable of lms(f)== lm(f_i), then it implies divisiable. 
	Example: specpoly=ab+ac+bc+d, f1=a+c+d*e, 
			lms(specpoly)=ab+ac; lm(f1)=a; 1st var of lms(specpoy) is a==lm(f1), so dividable.
4: update specpoly: specpoly=specpoly-lms(specpoly)+(f_i-lm(f_i))*	lms(specpoly)/lm(f_i)
5: go step 1 until all f_i are handled.
------------------------------------------------------------
The critical and most time-consuming step is Step 4, of which, there are 2 critical sub-steps:
1: (f_i-lm(f_i))*	lms(specpoly)/lm(f_i) 
2: addition between "specpoly-lms(specpoly)" and "(f_i-lm(f_i))*lms(specpoly)/lm(f1)"
The above step 1 takes about 90% running time and Step 2 only takes 10%.
So basically the problem now is how to efficiently compute polynomial multiplication?
Some attributes of these polynomials:
1) the two polynomials are sorted
2) In most time, one polynomial can be much longer the other one.
*/
//dd

double diffms1(0.0);
clock_t mbegin,mend;

double diffms2(0.0);
clock_t abegin,aend;

double diffms3(0.0);
clock_t fbegin,fend;

double diffms4(0.0);
clock_t t1begin,t1end;

double diffms5(0.0);

void reduce(list<monomial> & specpoly,vector< list<monomial> > &ideal )
{
//cout<<"in reduce"<<endl;
	begin=clock();

	list<monomial> first;//lms(specpoly); example: specpoly=a*b+a*c+d, then "first" contians a*b+a*c which contains the monomials with 1st same variable.
	
	monomial tempmon;
	monomial monone;//monomial for variable "1"
	
	
	list<monomial> tempoly, tempoly2;
	
	list<monomial>::iterator monit,monit2;
	
	list<monomial>::iterator tempit;
	list<monomial>::iterator specit, pre_specit;
	
	unsigned int rep1=VID["1"];//the index of number 1
	monone.insert(rep1);
	set<unsigned int>::iterator oneit;
	
	int firstvar; //first var (represented as number) of whole poly
	int res;
	int start=0;
	int gepo=0;
	
	firstvar=*((specpoly.begin())->begin());//

	/*initially, first=1*/
	first.push_back(monone);
	
	/*remove the 1st monomial; initial specpoly is: out1+out2+1
	 * after specpoly/f_1, out1 is cancelled.
	*/
	specpoly.pop_front();
cout<<"ideal size is: "<<ideal.size()<<endl;	
	/*start is the index of f_i*/
	while(start<ideal.size())
	{		
		/*******************************************/
		/*I use 1st var of f_i to determine whether specpoly is dividable by f_i*/
		if(firstvar == (*(ideal[start].front().begin()) ))//can be divided
		{
cout<<start<<"------------------------"<<endl;
//		cout<<"first: ";printpoly(first);	
		cout<<"remainder: ";printpoly(specpoly);	
			
cout<<"divided by: "; printpoly(ideal[start]);
			
		monit=ideal[start].begin();//the 1st monomial is always a single variable, so skip
		
			
		/*first=lms(specpoly)/lm(f_i); Note lm(f_i) is a variable. whether lms(specpoly)/lm(f_i)==1 */
		if( (*((first.begin())->begin()) )!=rep1 )//rep1 is the map value of "1"
		{
			/*The following two for loops are doing: (f_i-lm(f_i))*lms(specpoly)/lm(f1)
			 * ++monit means "f_i-lm(f_i)"
			 * result is storing in tempoly
			 * */
			 
			/*for each ideal[start][i]*first, creating a tempoly and summing them.*/ 
			/*1st step is to create the initial tempoly*/
			++monit;
			for(tempit=first.begin();tempit!=first.end();++tempit)
				{
					//mbegin=clock();	
					merge((*monit).begin(),(*monit).end(),(*tempit).begin(),(*tempit).end(),insert_iterator< monomial >(tempmon,tempmon.end()));
					//mend=clock();
					//diffms1+=((mend-mbegin)*1000);
					
					
					//oneit=tempmon.find(rep1);
					//if(oneit!=tempmon.end()) tempmon.erase(oneit);  //a*b*1*c => a*b*c
					if(((*(--tempmon.end()))==rep1) && ( *(tempmon.begin())!=rep1))
					tempmon.erase(--tempmon.end());
					
					
					abegin=clock(); 
					if(tempoly.begin()==tempoly.end())//Forbid using tempoly.size==0 which takes at least 3 times more time than current one
					{
					
					tempoly.push_back(tempmon);
					
					}
					else 
					//tempoly.get_allocator().allocate(500);
					{
						
						insertmon2poly(tempoly,tempmon);//takes 90% of the whole running time
						
					}	
					 aend=clock();
						diffms2+=((aend-abegin)*1000);	
					//tempoly.push_back(tempmon);
					tempmon.clear();
				}
				/*initial tempoly is done!*/
			
			for(++monit; monit!=ideal[start].end();++monit)
			{
				for(tempit=first.begin();tempit!=first.end();++tempit)
				{
					//mbegin=clock();	
					merge((*monit).begin(),(*monit).end(),(*tempit).begin(),(*tempit).end(),insert_iterator< monomial >(tempmon,tempmon.end()));
					//mend=clock();
					//diffms1+=((mend-mbegin)*1000);
					
					
					//oneit=tempmon.find(rep1);
					//if(oneit!=tempmon.end()) tempmon.erase(oneit);  //a*b*1*c => a*b*c
					if(((*(--tempmon.end()))==rep1) && ( *(tempmon.begin())!=rep1))
					tempmon.erase(--tempmon.end());
					
					
					abegin=clock(); 
					if(tempoly2.begin()==tempoly2.end())//Forbid using tempoly.size==0 which takes at least 3 times more time than current one
					{
					
					tempoly2.push_back(tempmon);
					
					}
					else 
					//tempoly.get_allocator().allocate(500);
					{
						
						insertmon2poly(tempoly2,tempmon);//takes 90% of the whole running time
						
					}	
					 aend=clock();
						diffms2+=((aend-abegin)*1000);	
					//tempoly.push_back(tempmon);
					tempmon.clear();
				}
				
				mergesort(tempoly,tempoly2);
				tempoly2.clear();
				
			}
		}	
		else/*if first==1,simplify (f_i-lm(f_i))*lms(specpoly)/lm(f1) */
		{
			//for(++monit; monit!=ideal[start].end();++monit)
			//tempoly.push_back(*monit);
			tempoly.splice(tempoly.begin(),ideal[start],++monit,ideal[start].end());
			//cout<<"1: "<<endl; printpoly(tempoly);
			//insertmon2poly(tempoly,tempmon);
		}	
		
		
		
		/*
		 * addition between "specpoly-lms(specpoly)" and "(f_i-lm(f_i))*lms(specpoly)/lm(f1)"
		 * "specpoly-lms(specpoly)" is stored in sepcpoly which has been sorted
		 * "(f_i-lm(f_i))*lms(specpoly)/lm(f1)" is stored in tempoly which has been sorted
		 * Implemented as a merge sort
		 * */
		//t1begin=clock();
		mergesort(specpoly,tempoly);	
		//t1end=clock();
		//diffms4+=((t1end-t1begin)*1000);	
		
cout<<"division result: "<<endl; printpoly(specpoly);
			
			
			tempoly.clear();
			first.clear();//delete the temp partial-poly
			
			firstvar=*((specpoly.begin())->begin());
			//if the first var of specpoly is 'i' then it is a PI. So stop!
			//there should be a better way to check PI. recored the value of first PI when reading all vars in.
			if(DIV[firstvar][0]=='i') break;
			
		//	cout<<firstvar<<endl;
			if(firstvar==rep1)  break;
			
			/*remove the leading variable and cut monomials without leading variable from "specpoly" to "first"**/
			/*Example: specpoly: (abcd+ade+bc+ce), after next step: specpoly:bc+ce; first: bcd+de */
			monit=specpoly.begin();
			///*handle the 1st monomial*/
			
			/*computing first; first=lms(specpoly)/lm(f_i); Note lm(f_i) is a variable.*/
			while((*(monit->begin()))==firstvar)
			{
				
				if(monit->size()==1)//a*b+a*c+a, if meeting "a", then break;
				{		
					//monit2=monit;	
					//++monit;
					//specpoly.erase(monit2);
					*monit=monone;
					++monit;
					break;//because the size is 1 measn single variable, so stop here
				}
				else
				{
					monit->erase(monit->begin());//first=lead(h)/lead(g[i]): (abcd+ade)/a=bcd+de
					++monit;//monit is impossible to reach end.
				}	
			}
			
			first.splice(first.begin(),specpoly,specpoly.begin(),monit);
			
			//continue;
		}
		else
		{
			++start;
		}
		/*******************************************/
		
	}	
	
	cout<<"final result is:"<<endl;
		printpoly(specpoly);
	end=clock();
	diffms+=((end-begin)*1000)/CLOCKS_PER_SEC;
	cout<<"total time elapsed: "<<diffms<<" ms, of which, multi took "<<(diffms1/CLOCKS_PER_SEC)<<" ms; poly mul took "<<(diffms2/CLOCKS_PER_SEC)<<" ms"<<endl;
	//cout<<"in function: "<<(diffms3/CLOCKS_PER_SEC)<<" ms"<<endl;
	//cout<<"merge out function: "<<(diffms4/CLOCKS_PER_SEC)<<" ms"<<endl;
	//cout<<"merge in function: "<<(diffms5/CLOCKS_PER_SEC)<<" ms"<<endl;
}


/*insertion order, insert tempmon into poly
 * when inserting, from end to begin
 * */
void insertmon2poly(list<monomial>& tempoly, monomial & tempmon)
{
	
		//fbegin=clock();
		//sorting first
		list<monomial>::iterator it; //about 5 times faster than reverse iterator.
		it=tempoly.end();
		int temp;
		--it;
	
		while(it!=tempoly.begin())
		{
			temp=CompareSet(tempmon,*it);
			if( temp==1)//temp > it
			{
				tempoly.insert(++it,tempmon);
				//fend=clock();
				//diffms3+=((fend-fbegin)*1000);
				
				return;
			}
			else if(temp==-1)
			--it;
			else if (temp==0) //same, delete
			{
				tempoly.erase(it);
				//fend=clock();
				//diffms3+=((fend-fbegin)*1000);
				
				return;
			}
			
		}
	
		temp=CompareSet(tempmon,*it);
		if( temp==1)//temp > it
		{
			tempoly.insert(++it,tempmon);
		}
		else if(temp==-1)
			tempoly.push_front(tempmon);
		else if (temp==0) //same, delete
		{
			tempoly.erase(it);
		}
		//fend=clock();
		//diffms3+=((fend-fbegin)*1000);	
		
}

/*merge sort of two sorted polys*/
void mergesort(list<monomial>& specpoly,list<monomial>& tempoly)
{
		/*
		 * addition between "specpoly-lms(specpoly)" and "(f_i-lm(f_i))*lms(specpoly)/lm(f1)"
		 * "specpoly-lms(specpoly)" is stored in sepcpoly which has been sorted
		 * "(f_i-lm(f_i))*lms(specpoly)/lm(f1)" is stored in tempoly which has been sorted
		 * Implemented as a merge sort
		 * */
		
		 list<monomial>::iterator tempit;
		 list<monomial>::iterator specit;
		 list<monomial>::iterator pre_specit;
		 int res;
		 
		tempit=tempoly.begin();
		specit=specpoly.begin();
			
		while( (tempit!=tempoly.end()) || (specit!=specpoly.end()) )
		{/*since specpoly is usually much longer than tempoly, we choose a different version of merge sort. different from CLRS book.*/
			if( (tempit!=tempoly.end()) && (specit!=specpoly.end()) )
			{	
				res=CompareSet(*tempit,*specit);
				if( res==1)//temp > spec
				{
					//newspecpoly.push_back(*specit);
					//cout<<"temp>spec: ";printpoly(newspecpoly);
					++specit;
				}
				else if(res==-1) //temp < spec
				{
					specpoly.insert(specit,*tempit);
					//newspecpoly.push_back(*tempit);
					//cout<<"temp<spec: ";printpoly(newspecpoly);
					++tempit;
				}
				else if (res==0) //temp =spec, delete
				{
						//cout<<"temp=spec: ";printpoly(newspecpoly);
						pre_specit=specit;
						++specit;
						++tempit;
						
						specpoly.erase(pre_specit);
						
						//if( (tempit==tempoly.end()) && (specit==specpoly.end()))
						//{
							//specpoly.clear();
							//specpoly.insert(specpoly.end(),newspecpoly.begin(),newspecpoly.end());
						//	break;
						//}
					}
				}
				else if(tempit==tempoly.end())//most possible case
				{
					//specpoly.erase(specpoly.begin(),specit);
					//specpoly.insert(specit,newspecpoly.begin(),newspecpoly.end());
					break;
				}
				else if(specit==specpoly.end())//less possible
				{
					//specpoly.clear();
					//specpoly.insert(specpoly.end(),tempit,tempoly.end());
					specpoly.splice(specpoly.end(),tempoly,tempit,tempoly.end());
					//specpoly.insert(specpoly.end(),tempit,tempoly.end());
					break;
				}
				
			}
					
}

/*clear global variables*/
void clear()
{	//begin=clock();
	tempmon.clear();
	glopoly.clear();
	specpoly.clear();
	ideal.clear();
	VID.clear();
	ind=2;		
//	end=clock();
	//double diffms2=((end-begin)*1000)/CLOCKS_PER_SEC;	
//	cout<<"clear takes "<<diffms2<<" ms"<<endl;
}
/********************************************/

void printmonomial(monomial & toprint)
{
	if(toprint.size()==0)
	{
		cout<<"0"<<endl;
		return;
	}	
	set<unsigned int>::iterator it;
	set<unsigned int>::iterator endit;

	endit=--toprint.end();
	for(it=toprint.begin();it!=endit;++it)
	{
		cout<<DIV[*it]<<"*";
	}

	cout<<DIV[*it];
	
}

void printpoly(list<monomial> &toprint)
{
	if(toprint.size()==0)
	{
		cout<<"0"<<endl;
		return;
	}	
	list<monomial>::iterator it;
	list<monomial>::iterator endit;
	endit=--toprint.end();
	for(it=toprint.begin();it!=endit;++it)
	{
		printmonomial(*it);
		cout<<"+";
	}
	printmonomial(*it);
	cout<<endl;
}

void printideal(vector< list<monomial> > &toprint)
{
	if(toprint.size()==0)
	{
		cout<<"0"<<endl;
		return;
	}	
	vector< list<monomial> >::iterator it;
	for(it=toprint.begin();it!=toprint.end();++it)
	{
		printpoly(*it);
		cout<<endl;
	}
}

void printmap()
{
	map<string, unsigned int>::iterator it;
	for(it=VID.begin();it!=VID.end();++it)
	cout<<it->first<<"-->"<<it->second<<endl;
}

