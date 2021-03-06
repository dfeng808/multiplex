'''
Created on 09.04.2014

@author: apopiel
'''
from graph.method.lbp.NetworkUtils import NetworkUtils
cimport numpy as np
DTYPE=np.float64
ctypedef np.float64_t DTYPE_t
import random
import operator

cdef class CrossValMethods:
    '''
    classdocs
    '''


    def __cinit__(self):
        '''
        Constructor
        '''

    cpdef list flatCrossVal(self, list items, int numberOfFolds, graph, int nrOfNodes,
                      defaultClassMat, int lbpSteps, float lbpThreshold, object k_fold_cross_validation,
                      object separationMethod, object lbp, list layerWeights, isRandomWalk, float percentOfKnownNodes, object adjMatPrep,
                      object prepareLayers, object prepareClassMat):
        utils = NetworkUtils()
        cdef list fold_sum = []
        cdef int i
        for i in range(0,nrOfNodes,1):
            fold_sum.append([i,0,0])
        cdef int fold_number = 1
        cdef list training
        cdef list validation
        cdef list results_agregator
        cdef int num_of_res
        cdef list sum
        cdef int iter
        for training, validation in k_fold_cross_validation(items, numberOfFolds):
            print "-----FOLD %d-----" % fold_number
            #separate layers
            results_agregator = []
            num_of_res = 0
            class_Mat, adjMat, nodes = separationMethod(graph, defaultClassMat, validation)


                #-------------LBP----------------------
            class_mat, i = lbp(adjMat, class_Mat, lbpSteps, lbpThreshold, training, validation)
            #create zero result matrix
            sum = []
            for node in nodes:
                if (node.id in validation):
                    sum.append([node.id,class_mat[node.id,0],class_mat[node.id,1]])
                else:  
                    sum.append([node.id,0,0])
            sorted_sum = utils.sort_sum(sum)
            #fusion - sum
            for i in range(0,nrOfNodes,1):
                fold_sum[i][1]+=sorted_sum[i][1]
                fold_sum[i][2]+=sorted_sum[i][2]
            # print sum
            fold_number = fold_number + 1
        return fold_sum

    cpdef multiLayerCrossVal(self, list items, int numberOfFolds, graph, int nrOfNodes,
                     np.ndarray defaultClassMat, int lbpSteps, float lbpThreshold, k_fold_cross_validation,
                     separationMethod, lbp, list layerWeights, isRandomWalk, float percentOfKnownNodes, prepareAdjMat, prepareLayers, prepareClassMat):
        cdef int fold_number = 1
        cdef list fold_sum = []
        cdef int i
        for i in range(1,nrOfNodes+1,1):
            fold_sum.append([i,0,0])
            
        cdef np.ndarray fuz_mean_occ = np.array([])
        prepareLayers(graph, layerWeights, defaultClassMat)
        cdef list adjTransMatrixes = []
        cdef list training
        cdef list validation
        cdef list results_agregator
        cdef num_of_res
        cdef int layer_label
        cdef np.ndarray class_mat
        cdef list results
        cdef res
        cdef int iter
        cdef int node
        cdef list full_res
        cdef np.ndarray n
        cdef list sum
        cdef list result
        cdef np.float64_t sumElement
        cdef rows
        cdef repmatInput
        cdef list rwp_result = []
        fusion_mean = self.prepare_sum_for_fusion_mean(nrOfNodes)
        fusion_layer = []
        fusion_random = []
        fusion_convergence_max = []
        fusion_convergence_min = []
        layer_results = {}
        for l in layerWeights:
            layer_results[l] = []
        for i in range(0,nrOfNodes,1):
            fusion_layer.append([i,0,0])
            fusion_random.append([i,0,0])
            fusion_convergence_max.append([i,0,0])
            fusion_convergence_min.append([i,0,0])
            for l in layerWeights:
                layer_results[l].append([i,0,0])


        for training, validation in k_fold_cross_validation(items, numberOfFolds):
            map_iterations = {}
            adjTransMatrixes = []
            print 'Multilayer method'
            print "-----FOLD %d-----" % fold_number
            #separate layers
            results_agregator = []
            num_of_res = 0
            
            
            for layer_label in layerWeights:
                prepareClassMat(layer_label, training)
                class_Mat, adjMat, nodes = separationMethod(layer_label)
                    
                for i in range(nrOfNodes):
                    if i >=class_Mat.shape[0]:
                        try:
                            self.training.remove(i)
                        except ValueError:
                            pass
                for i in range(nrOfNodes):
                    if i >=class_Mat.shape[0]:
                        try:
                            self.validation.remove(i)
                        except ValueError:
                            pass
                        
                if (isRandomWalk):
                    results = []
                    adjMat = prepareAdjMat(adjMat,graph)
                    adjTransMatrixes.append(adjMat)
                    class_mat, iterations = lbp(adjTransMatrixes, results, class_Mat, training, lbpSteps, lbpThreshold)
                else:    
                    #-------------LBP----------------------
                    class_mat, iterations = lbp(adjMat, class_Mat, lbpSteps, lbpThreshold, training, validation)
                map_iterations[layer_label] = iterations
                res = []
                iter = 0
                #assign results to nodes
                for node in nodes:
                    res.append([node,class_mat[iter,0],class_mat[iter,1]])
                    iter+=1
                    
                #assign results to full node list
                res = np.asarray(sorted(res))

                full_res = []
                iter = 0
                for n in res:
                    while iter!= n[0] or iter >= nrOfNodes:
                        full_res.append([iter,0,0])
                        iter+=1
                    full_res.append([iter,n[1],n[2]])
                    iter+=1
                    
                #push out results
                results_agregator.append(full_res)
                num_of_res += 1
            
            
            #create zero result matrix
            sum = []
            for i in range(1,nrOfNodes+1,1):
                sum.append([i,0,0])
            
            #fusion - sum
            for result in results_agregator:
                for i in range(0,nrOfNodes,1):
                    sum[i][1]+=result[i][1]
                    sum[i][2]+=result[i][2]
            for i in range(0,nrOfNodes,1):
                if i in validation:
                    fold_sum[i][1]+=sum[i][1]
                    fold_sum[i][2]+=sum[i][2]
            # print sum
            fusion_mean = self.prepare_fusion_mean(results_agregator, separationMethod, layerWeights, nrOfNodes, fusion_mean, validation)
            rwp_result = self.collect_rwp_lbp_result(isRandomWalk, layerWeights, results_agregator, rwp_result, validation)
            fusion_layer, fusion_random = self.calculate_fusions(fusion_layer, fusion_random, results_agregator, validation)

            fusion_convergence_max, fusion_convergence_min = self.calculate_fusion_convergence(fusion_convergence_max, fusion_convergence_min, map_iterations, results_agregator, validation)
            layer_results = self.calculate_results_for_layers(layer_results, results_agregator, validation)


            fold_number = fold_number + 1
        return fold_sum, fusion_mean, fusion_layer, fusion_random, fusion_convergence_max, fusion_convergence_min, layer_results, rwp_result

    def calculate_results_for_layers(self, layer_results, results_agregator, validation):
        i = 0
        for layer_res in results_agregator:
            i = i + 1
            for res in layer_res:
                node_id = res[0]
                if node_id in validation:
                    layer_results[i][node_id][1] = res[1]
                    layer_results[i][node_id][2] = res[2]
        print 'Layer results: ' + str(layer_results)
        return layer_results

    def calculate_fusion_convergence(self, fusion_convergence_max, fusion_convergence_min, map_iterations, results_agregator, validation):
        max_layer = max(map_iterations.iteritems(), key=operator.itemgetter(1))[0]
        min_layer = min(map_iterations.iteritems(), key=operator.itemgetter(1))[0]
        max_results = results_agregator[max_layer]
        min_results = results_agregator[min_layer]
        for elem in max_results:
            node_id = elem[0]
            if node_id in validation:
                fusion_convergence_max[node_id][1] = elem[1]
                fusion_convergence_max[node_id][2] = elem[2]
        for elem in min_results:
            node_id = elem[0]
            if node_id in validation:
                fusion_convergence_min[node_id][1] = elem[1]
                fusion_convergence_min[node_id][2] = elem[2]
        return fusion_convergence_max, fusion_convergence_min

    def calculate_fusions(self, fusion_layer, fusion_random, results_agregator, validation):
        for row in fusion_layer:
            node_id = row[0]
            if node_id in validation:
                map_max = {0:0.0, 1:0.0}
                list_of_results = []
                for single_res in results_agregator:
                    res_for_node = filter(lambda r: r[0] == node_id, single_res)[0]
                    list_of_results.append(res_for_node)
                    if res_for_node[1] > map_max[0]:
                        map_max[0] = res_for_node[1]
                    if res_for_node[2] > map_max[1]:
                        map_max[1] = res_for_node[2]
                if map_max[0] >= map_max[1]:
                    fusion_layer[node_id][1] = 1
                    fusion_layer[node_id][2] = 0
                else:
                    fusion_layer[node_id][2] = 1
                    fusion_layer[node_id][1] = 0
                choice = random.choice(list_of_results)
                fusion_random[node_id][1] = choice[1]
                fusion_random[node_id][2] = choice[2]
        return fusion_layer, fusion_random


    def collect_rwp_lbp_result(self, isRandomWalk, layerWeights, results_agregator, rwp_result, validation):
        if (isRandomWalk):
            nr_of_layers = len(layerWeights)
            last_result = results_agregator[nr_of_layers - 1]
            last_result = filter(lambda res: res[0] in validation, last_result)
            last_result = sorted(last_result, key=lambda row: row[0])
            rwp_result = rwp_result + last_result
        rwp_result = sorted(rwp_result, key=lambda row : row[0])
        return rwp_result

    def prepare_fusion_mean(self, results_agregator, separation_method, layer_weights, nr_of_nodes, fusion_mean, validation):
        i = 0
        sum_of_classes = {}
        for results_on_layer in results_agregator:
            layer = layer_weights[i]
            results_on_layer = filter(lambda res : res[0] in validation, results_on_layer)
            results_on_layer = sorted(results_on_layer, key=lambda row : row[0])

            sum_of_classes = self.analyse_result_in_layer(results_on_layer, sum_of_classes)
            i += 1
        fusion_mean = self.execute_fusion_mean(fusion_mean, layer_weights, sum_of_classes)
        return fusion_mean

    def collect_result(self, node_id, sum_of_classes, class_to_add):
        if sum_of_classes.has_key(node_id):
            current_classes_list = sum_of_classes.get(node_id)
            current_classes_list.append(class_to_add)
            sum_of_classes[node_id] = current_classes_list
        else:
            sum_of_classes[node_id] = [class_to_add]
        return sum_of_classes

    def analyse_result_in_layer(self, results_on_layer, sum_of_classes):
        for result in results_on_layer:
            node_id = result[0]
            if result[1] >= result[2]:
                sum_of_classes = self.collect_result(node_id, sum_of_classes, 0)
            else:
                sum_of_classes = self.collect_result(node_id, sum_of_classes, 1)
        return sum_of_classes

    def execute_fusion_mean(self, fusion_mean, layer_weights, sum_of_classes):
        for node_id in sum_of_classes.keys():
            average_class = round(sum(sum_of_classes[node_id]) / float(len(layer_weights)))
            if (average_class) == 0.0:
                fusion_mean[node_id][1] = 1
                fusion_mean[node_id][2] = 0
            else:
                fusion_mean[node_id][1] = 0
                fusion_mean[node_id][2] = 1
        return fusion_mean

    def prepare_sum_for_fusion_mean(self, nrOfNodes):
        sum_for_fusion_mean = []
        for j in xrange(0, nrOfNodes, 1):
            sum_for_fusion_mean.append([j, 0, 0])
        return sum_for_fusion_mean
