from sage.all import *

load('../Packages/balancefunctions.sage') 


# openBalanced = Graph({1 : [2,4], 2 : [1, 3, 4, 6], 3: [2, 4], 4: [1, 2, 3, 5], 5: [4, 6], 6: [2, 5]})
# closedBalanced = Graph({1 : [2,4,7], 2 : [3, 4, 6, 8], 3: [4, 9], 4: [5, 10], 5: [6, 11], 6: [12]})

# opentoClosed(openBalanced)

gHolder = Graph()

n_val = 4

for g in graphs(n_val):
    if isBalanced_open(g):
        gHolder = opentoClosed(g)
        #print("-- Original Graph --")
        #g.show()
        #print("-- Closed Graph --")
        #print(gHolder.edges())
        #gHolder.show()
        print("Closed appending of Graph is balanced:", isBalanced(gHolder))
        print("-----------------------------------------\n\n")