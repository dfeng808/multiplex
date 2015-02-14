'''
Created on 24 mar 2014

@author: Adek
'''
import networkx as nx
import numpy as np
import re
from random import shuffle
from graph.method.lbp.LoopyBeliefPropagation import LoopyBeliefPropagation
from graph.gen.Node import Node
cimport cython
import numpy.matrixlib.defmatrix as defmatrix
cimport numpy as np
cdef class LBPTools:
    '''
    classdocs
    '''

    

    def __cinit__(self, int nrOfNodes, graph, np.ndarray defaultClassMat, int lbpMaxSteps, float lbpThreshold, int percentOfTrainingNodes):
        self.nrOfNodes = nrOfNodes
        self.graph = graph
        self.defaultClassMat = defaultClassMat
        self.lbpMaxSteps = lbpMaxSteps
        self.lbpThreshold = lbpThreshold

        self.percentOfTrainingNodes = percentOfTrainingNodes
        self.folds = dict()
        self.adjMats = dict()
        self.nodes = dict()
        self.classMats = dict()
        self.graphs = dict()
        self.rests = dict()
        '''
        Constructor
        '''
    
    
    cdef list prepareUnobservdRow(self, int nrOfClasses):
        cdef list row = []
        cdef int i
        for i in range(0, nrOfClasses):
            row.append(0.5)
        return row
    
    cdef list prepareEmptyRow(self, int nrOfClasses):
        cdef list row = []
        cdef int i
        for i in range(0, nrOfClasses):
            row.append(0.0)
        return row
    
    #cross validation random fold set generator
    def k_fold_cross_validation(self, list items, int k, float percentOfKnownNodes, randomize=False):
        # print ('Percent of known nodes %s' % percentOfKnownNodes)
        cdef float trainignFoldsFloat = k*percentOfKnownNodes
        cdef int trainignFolds = int(trainignFoldsFloat)
        cdef int validationFolds = k-trainignFolds
        # print('Nr of training folds %s:' % trainignFolds)
        # print('Nr of validation folds %s:' % validationFolds)
        if randomize:
            items = list(items)
            shuffle(items)
        cdef list slices
        cdef int i
        cdef list validation = []
        cdef list training
        cdef list s
        cdef int item
        cdef int j
        cdef int index
        for i in xrange(k):
            slices = [items[x::k] for x in xrange(k)]
            # print slices
            validation = []
            training = []
            for j in xrange(k):
                index = i + j
                if (index >= k):
                    index -= k
                if (j < validationFolds):
                    if (validation.__len__() == 0):
                        validation = slices[index]
                    else:
                        validation += slices[index]
                    # print ('Index %i added as validation ' % index)
                else:
                    if (training.__len__() == 0):
                        training = slices[index]
                    else:
                        training += slices[index]
                    # print ('Index %i added as training ' % index)
            training = sorted(training)
            validation = sorted(validation)
            yield training, validation
    
    cpdef giveCorrectData(self, int label):
        # print ('Give correct data %s '% label)
        # print self.folds.get(str(label))
        # print self.adjMats.get(str(label))
        # print self.nodes.get(str(label))
        return self.folds[str(label)], self.adjMats[str(label)], self.nodes[str(label)]
        
    cpdef np.ndarray giveCorrectClassMat(self, int label):
        self.folds[str(label)] = self.classMats[str(label)].copy()
        # print ('Give correct data %s '% label)
        # print self.folds[str(label)]
        return self.folds[str(label)]
    
    cdef void addToGraph(self, g, n0, n1, set nodes, np.ndarray classMat, list training, int nrOfClasses, edge):

        if not g.has_node(n0):
            nodes.add(n0)
#             if n0.id not in training:
#                 row = self.prepareUnobservdRow(nrOfClasses)
#                 classMat[n0.id] = row
        if not g.has_node(n1):
            nodes.add(n1)
#             if n1.id not in training:
#                 row = self.prepareUnobservdRow(nrOfClasses)
#                 classMat[n1.id] = row
        
        g.add_edge(n0.id, n1.id, edge[2])  
        
    cpdef prepareClassMatForFold(self, int layer, list training):
        cdef int i = 0
        cdef np.ndarray classMat = self.giveCorrectClassMat(layer)
        cdef int nrOfClasses = classMat.shape[1]
        cdef np.ndarray node
        cdef np.ndarray rowCurr
        cdef int int1
        cdef int int2
        cdef list row
        for node in classMat:
            if i not in training:
                rowCurr = classMat[i]
                int1 = rowCurr[0] 
                int2 = rowCurr[1]
                if (int1 != 0.0 or int2 != 0.0):
                    row = self.prepareUnobservdRow(nrOfClasses)
                    classMat[i] = row
            i = i + 1
        print 'prepare classmat'
        print classMat
         
    cpdef separate_layer(self, graph, list layers, np.ndarray defaultClassMat, list training):
        print 'Enter separate layer'
        print self.folds
        for i in layers:
            self.classMats[str(i)] = defaultClassMat.copy()
            self.graphs[str(i)] = nx.Graph()
            self.nodes[str(i)] = set([])
        cdef int nrOfClasses = self.classMats[str(1)].shape[1]
        cdef int label
        cdef str temp
        for edge in graph.edges(data=True):
            for label in layers:
                temp = ".*'layer': 'L"+str(label)+"'.*"
                #layer filter
                if re.match( str(temp),str(edge)):
                    break
            n0 = edge[0]
            n1 = edge[1]
            self.addToGraph(self.graphs[str(label)], n0, n1, self.nodes[str(label)], self.classMats[str(label)], training, nrOfClasses, edge)
          
        cdef set gNodes = set(graph.nodes())

        for i in layers:
            self.rests[str(i)] = gNodes.difference(self.nodes[str(i)])
        for i in layers:
            print i
            print self.nodes[str(i)]
            print self.rests[str(i)]
            print self.classMats[str(i)]
            self.classMats[str(i)], self.adjMats[str(i)], self.nodes[str(i)] = self.fillEmptyRow(self.graphs[str(i)],
                                                                                                 self.rests[str(i)],
                                                                                                 self.nodes[str(i)],
                                                                                                 nrOfClasses,
                                                                                                     self.classMats[str(i)])
    cdef fillEmptyRow(self, g, set rest, set nodes, int nrOfClasses, np.ndarray classMat):
        cdef list row
        cdef list sortedNodes
        cdef np.ndarray adjMat
        for node in rest:
            nodes.add(node)
            row = self.prepareEmptyRow(nrOfClasses)
            classMat[node.id] = row
            g.add_node(node.id)
        
        sortedNodes = sorted(g.nodes())
        adjMat = nx.adjacency_matrix(g, sortedNodes, weight = None)
        cdef np.ndarray out_nodes = np.asarray(nx.nodes(g))
        return classMat, adjMat, out_nodes
    
    cpdef list prepareToEvaluate(self, list lbpClassMat, int nrOfClasses):
        cdef list classMatForEv = []
        cdef int i
        cdef int maxi
        cdef int j
        for i in range(0, lbpClassMat.__len__()):
            maxi = 1
            for j in range(2, nrOfClasses+1):
                if (lbpClassMat[i][j] > lbpClassMat[i][maxi]):
                    maxi = j
            classMatForEv.append(maxi-1)
        return classMatForEv
    
    cpdef crossVal(self, list items, int numberOfFolds, graph, int nrOfNodes,
                     np.ndarray defaultClassMat, int lbpSteps, float lbpThreshold,
                     k_fold_cross_validation, separationMethod, lbp, list layerWeights, crossValMethod, isRandomWalk, percentOfKnownNodes, adjMarPrep, prepareLayers, prepareClassMat):
        return crossValMethod(items, numberOfFolds, graph, nrOfNodes,
                     defaultClassMat, lbpSteps, lbpThreshold, k_fold_cross_validation, separationMethod, lbp, layerWeights, isRandomWalk, percentOfKnownNodes, adjMarPrep, prepareLayers, prepareClassMat)