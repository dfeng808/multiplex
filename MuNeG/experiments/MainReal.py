'''
Created on 18 mar 2014

@author: Adek
'''
#1 - stratified xval
#2 therefore used xval

import sys
sys.path.append('/home/apopiel/multiplex/MuNeG/')
from experiments.DecisionFusionReal import DecisionFusion
from graph.reader.DanioRerio.DanioRerioReader import DanioRerioReader


def execute_experiment(fun, method, folds):
    global df
    df = DecisionFusion(method, folds, fun)
    df.processExperiment()


if __name__ == '__main__':

    for x_val_method in [1, 2]:
        if x_val_method == 1:
            for fold in [2.0, 3.0, 4.0, 5.0, 10.0, 20.0]:
                execute_experiment(sys.argv[1], x_val_method, fold)
        else:
            for percent_known_nodes in [0.2, 0.4, 0.6, 0.8]:
                execute_experiment(sys.argv[1], x_val_method, percent_known_nodes)


