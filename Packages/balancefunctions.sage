from sage.all import *
import os
import sys

## Pre-existing Balancing Functions
def random_color(n): #colors are red and blue, for use in making nice pictures
    D = {}
    redlist = []
    bluelist = []
    for i in range(n):
        x=random()
        if x < 0.5:
            redlist.append(i)
        else:
            bluelist.append(i)
    D["red"]=redlist
    D["blue"]=bluelist
    return D

def randomly_color_vertices(g): #colors are 1 and -1
    n = g.order()
    D = {}
    for i in range(n):
        if random() < 0.5:
            D[i]=1
        else:
            D[i] = -1
    g.set_vertices(D)
    return g

def balance_number_vertex(g,v):#assumes g is labeled with 1, -1
    N=g.neighbors(v)
    D=g.get_vertices()
    balance = D[v]
    for w in N:
        balance += D[w]
    return abs(balance)

def balance_number_vertex_open(g,v):#assumes g is labeled with 1, -1
    N = g.neighbors(v) 
    D = g.get_vertices()
    balance = 0        
    for w in N:
        balance += D[w]  
    return abs(balance)

def balance_number_given_coloring(g): #assumes g comes with a coloring (dictionary)
    balance = 0
    for v in g.vertices():
        balance += balance_number_vertex(g,v)
    return balance

def balance_number_given_coloring_open(g): #assumes g comes with a coloring (dictionary)
    balance = 0
    for v in g.vertices():
        balance += balance_number_vertex_open(g,v)
    return balance

def label_iterator(n,labels=[1,-1]): #generate all lists of  things from the input labels list [1,-1]
    if n == 0:
        yield []
    else:
        for label_list in label_iterator(n-1,labels):
            for label in labels:
                yield label_list + [label]

#given graph g, denerate every coloring, find the balance number, record the minimum
def best_balanced_coloring(g):
    n = g.order()
    graph_vertices_sorted = g.vertices(sort=True) # Get actual vertex names, sorted
    color_iter = label_iterator(n) # Generates lists of colors [c0, c1, ..., c_{n-1}]
    best = infinity 
    best_coloring = {}
    for coloring_list in color_iter:
        # Map the i-th color in coloring_list to the i-th vertex in graph_vertices_sorted
        color_dict = {graph_vertices_sorted[i]: coloring_list[i] for i in range(n)}
        g.set_vertices(color_dict)
        test = balance_number_given_coloring(g)
        if test < best:
            best_coloring = color_dict
            best = test
    return best_coloring

def best_balanced_coloring_open(g): # Apply the same fix here
    n = g.order()
    graph_vertices_sorted = g.vertices(sort=True) # Get actual vertex names, sorted
    color_iter = label_iterator(n) # Generates lists of colors [c0, c1, ..., c_{n-1}]
    best = infinity
    best_coloring = {}
    for coloring_list in color_iter:
        # Map the i-th color in coloring_list to the i-th vertex in graph_vertices_sorted
        color_dict = {graph_vertices_sorted[i]: coloring_list[i] for i in range(n)}
        g.set_vertices(color_dict)
        test = balance_number_given_coloring_open(g)
        if test < best:
            best_coloring = color_dict
            best = test
    return best_coloring


def balance_number(g):
    coloring_dict = best_balanced_coloring(g)
    g.set_vertices(coloring_dict)
    return balance_number_given_coloring(g)

def balance_number_open(g):
    coloring_dict = best_balanced_coloring_open(g)
    g.set_vertices(coloring_dict)
    return balance_number_given_coloring_open(g)

def isBalanced(g):
    return balance_number(g) == 0

def isBalanced_open(g):
    return balance_number_open(g) == 0


# New Balancing functions
def opentoClosed(g):

    closedG = g.copy()
    vCounter = closedG.num_verts()

    for v in closedG.vertices():
        leaf = vCounter
        closedG.add_vertex(leaf)
        closedG.add_edge(v, leaf)
        vCounter += 1 

    return closedG



## Wrapped functions

def graph_order(g): return g.order() # If you want to call it 'graph_order'
def graph_size(g): return g.size()   # If you want to call it 'graph_size'

def diameter(g): # Using the direct name the worker is looking for
    if g.is_connected(): 
        val = g.diameter()
        return -1 if val == infinity else int(val)
    return -1 

def chromatic_number(g): return g.chromatic_number() # Name 'chromatic_number'

def is_connected(g): return int(g.is_connected()) # Name 'is_connected'

def average_distance(g): # Name 'average_distance'
    if g.is_connected():
        try:
            avg_dist = g.average_distance()
            return -1.0 if avg_dist == infinity else float(avg_dist)
        except Exception: return -2.0 # Placeholder for error
    return -1.0 

def girth(g): # Name 'girth'
    try:
        gi = g.girth()
        return -1 if gi == infinity else int(gi)
    except Exception: return -2.0

def radius(g): # Name 'radius'
    if not g.is_connected(): return -1.0
    try:
        rad = g.radius()
        return -1 if rad == infinity else int(rad)
    except Exception: return -2.0

def wiener_index(g): # Name 'wiener_index'
    if not g.is_connected(): return -1.0
    try:
        wi = g.wiener_index()
        return -1.0 if wi == infinity else float(wi)
    except Exception: return -2.0

def szeged_index(g): # Name 'szeged_index'
    if not g.is_connected(): return -1.0
    try:
        # Check if the method exists, as it's not always standard on Graph object
        if hasattr(g, 'szeged_index') and callable(g.szeged_index):
            sz = g.szeged_index()
            return -1.0 if sz == infinity else float(sz)
        else:
            # If you have a global szeged_index function from another loaded file,
            # this worker won't see it unless that file is loaded in worker_funcs.py
            # For now, assume we want g.szeged_index() if it exists.
            # If it's a critical invariant from graph_theory.py, ensure graph_theory.py
            # defines it as a top-level function and worker_funcs.py loads graph_theory.py.
            return -3.0 # Placeholder: method not on graph object
    except Exception: return -2.0


def size(g):
    return g.size()

def average_degree(g):
    return g.average_degree()

# In Packages/balancefunctions.sage
# Ensure 'from sage.all import *' and 'import os, sys' are at the top of this file

#def lovasz_theta(g): # Or name it 'lovasz_theta' if that's the name used in your list
    ug = g
    if g.is_directed():
        ug = g.to_undirected()

    try:
        # Optional: One-time warning if Sage itself reports CSDP is missing
        # This check might need sage.features to be importable
        if not lovasz_theta.__dict__.get('_csdp_warning_printed', False):
            try:
                if not sage.features.csdp.CSDP().is_present():
                    print(f"WORKER (pid {os.getpid()}) INFO: Sage indicates CSDP optional package not found. Lovasz theta might be using a fallback, be slow, or error.", file=sys.stderr)
                lovasz_theta._csdp_warning_printed = True
            except Exception: # In case sage.features itself has issues
                lovasz_theta._csdp_warning_printed = True # Avoid re-checking

        theta = ug.lovasz_theta() # Attempt to call it

        if theta == infinity or theta == -infinity: # Handle potential infinite results
            return -1.0 # Placeholder for infinity
        return float(theta)
    except TypeError as te:
        # Specifically catch the 'range' + 'range' TypeError
        if "unsupported operand type(s) for +: 'range' and 'range'" in str(te):
            if not lovasz_theta.__dict__.get('_type_error_warning_printed', False): # Print once
                print(f"WORKER (pid {os.getpid()}) INFO: Known TypeError in lovasz_theta fallback for graph like {ug.graph6_string()[:10]}... Returning placeholder.", file=sys.stderr)
                lovasz_theta._type_error_warning_printed = True
            return -3.0 # Specific placeholder for this known TypeError
        else: # Handle other TypeErrors
            print(f"WORKER (pid {os.getpid()}) Other TypeError in lovasz_theta for {ug.graph6_string()[:10]}...: {te}", file=sys.stderr)
            return -4.0 
    except RuntimeError as re: # Catching other runtime errors (e.g., from a solver if one was found but failed)
        print(f"WORKER (pid {os.getpid()}) RuntimeError in lovasz_theta for {ug.graph6_string()[:10]}...: {re}", file=sys.stderr)
        return -2.0 
    except Exception as e: # Catch any other unexpected errors
        print(f"WORKER (pid {os.getpid()}) Unexpected error in lovasz_theta for {ug.graph6_string()[:10]}...: {type(e).__name__}: {e}", file=sys.stderr)
        return -5.0