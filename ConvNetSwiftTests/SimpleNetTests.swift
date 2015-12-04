//
//  SimpleNetTests.swift
//  ConvNetSwift
//
//  Created by Alex Sosnovshchenko on 11/3/15.
//  Copyright © 2015 OWL. All rights reserved.
//

import XCTest

class SimpleNetTests: XCTestCase {
    var net: Net?
    var trainer: Trainer?
    
    override func setUp() {
        super.setUp()
        srand48(time(nil))

        net = Net()
        
        let input = InputLayerOpt(out_sx:1, out_sy:1, out_depth:2)
        let fc1 = FullyConnLayerOpt(num_neurons:5, activation:.tanh)
        let fc2 = FullyConnLayerOpt(num_neurons:5, activation:.tanh)
        let softmax = SoftmaxLayerOpt(num_classes: 3)
        let layer_defs: [LayerOptTypeProtocol] = [input, fc1, fc2, softmax]
        
        net!.makeLayers(layer_defs)
        
        var trainerOpts = TrainerOpt()
        trainerOpts.learning_rate = 0.0001
        trainerOpts.momentum = 0.0
        trainerOpts.batch_size = 1
        trainerOpts.l2_decay = 0.0
        trainer = Trainer(net: net!, options: trainerOpts)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    //should be possible to initialize
    func testInit() {
        
        // tanh are their own layers. Softmax gets its own fully connected layer.
        // this should all get desugared just fine.
        XCTAssertEqual(net!.layers.count, 7)
    }
    
    //should forward prop volumes to probabilities
    func testForward() {
        
        var x = Vol(array: [0.2, -0.3]);
        let probability_volume = net!.forward(&x)
        
        XCTAssertEqual(probability_volume.w.count, 3)  // 3 classes output
        var w = probability_volume.w;
        for(var i=0;i<3;i++) {
            XCTAssertGreaterThan(w[i], 0.0)
            XCTAssertLessThan(w[i], 1.0)
        }
        
        XCTAssertEqualWithAccuracy(w[0]+w[1]+w[2], 1.0, accuracy: 0.000000000001)
    }
    
    //should increase probabilities for ground truth class when trained
    func testTrain() {
        
        // lets test 100 random point and label settings
        // note that this should work since l2 and l1 regularization are off
        // an issue is that if step size is too high, this could technically fail...
        for(var k=0; k<100; k++) {
            var x = Vol(array: [RandUtils.random_js() * 2 - 1, RandUtils.random_js() * 2 - 1]);
            let pv = net!.forward(&x);
            let gti = Int(RandUtils.random_js() * 3);
            let train_res = trainer!.train(x: &x, y: gti);
            print(train_res)
            
            let pv2 = net!.forward(&x);
            XCTAssertGreaterThan(pv2.w[gti], pv.w[gti])
        }
    }
    
    //should compute correct gradient at data
    func testGrad() {
        
        // here we only test the gradient at data, but if this is
        // right then that's comforting, because it is a function
        // of all gradients above, for all layers.
        
        var x = Vol(array: [RandUtils.random_js() * 2.0 - 1.0, RandUtils.random_js() * 2.0 - 1.0]);
        let gti = Int(RandUtils.random_js() * 3); // ground truth index
        let res = trainer!.train(x: &x, y: gti); // computes gradients at all layers, and at x
        
        print(res)
        
        /*
        TrainResult(
        fwd_time: 9223372036854775807, 
        bwd_time: 9223372036854775807, 
        l2_decay_loss: 0.0, 
        l1_decay_loss: 0.0, 
        cost_loss: 0.784027673681949, 
        softmax_loss: 0.784027673681949, 
        loss: 0.784027673681949)
        */
        
        /* js:
        bwd_time: 1
        cost_loss: 0.8871066776430543
        fwd_time: 0
        l1_decay_loss: 0
        l2_decay_loss: 0
        loss: 0.8871066776430543
        softmax_loss: 0.8871066776430543
        */
        
        let delta = 0.000001;
        
        for i: Int in 0 ..< x.w.count {
            //            let grad_analytic1 = (net?.layers.first! as! InputLayer).in_act!.dw[i]
            //            let grad_analytic2 = (net?.layers.last! as! SoftmaxLayer).in_act!.dw[i]
            
            let grad_analytic = x.dw[i];
            
            let xold = x.w[i];
            x.w[i] += delta;
            let c0 = net!.getCostLoss(V: &x, y: gti);
            x.w[i] -= 2*delta;
            let c1 = net!.getCostLoss(V: &x, y: gti);
            x.w[i] = xold; // reset
            
            let grad_numeric = (c0 - c1)/(2.0 * delta);
            let rel_error = abs(grad_analytic - grad_numeric)/abs(grad_analytic + grad_numeric);
            print("\(i): numeric: \(grad_numeric), analytic: \(grad_analytic) => rel error \(rel_error)");
            
            /* js:
            0: numeric: -0.18889002029176538, analytic: -0.18886165813376557 => rel error 0.00007508148770648791
            1: numeric: 0.05234599215198088, analytic: 0.05234719879335431 => rel error 0.000011525500011363902
            */
            
            XCTAssertLessThan(rel_error, 1e-2)
            
        }
    }
}
