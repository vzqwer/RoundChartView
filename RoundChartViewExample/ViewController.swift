//
//  ViewController.swift
//  RoundChartViewExample
//
//  Created by Oleg Shulakov on 07.03.2022.
//

import UIKit

class ViewController: UIViewController {

    lazy var chartView: RoundChartView = {
        let chartView = RoundChartView()
        chartView.backgroundColor = .clear
        chartView.translatesAutoresizingMaskIntoConstraints = false
        return chartView
    }()
    lazy var button: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(randomSections), for: .touchUpInside)
        button.setTitle("Random sections", for: .normal)
        button.setTitleColor(.blue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(chartView)
        view.addSubview(button)
        
        setupLayout()
    }
    
    func setupLayout() {
        let size: CGFloat = 160
        NSLayoutConstraint.activate([
            chartView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            chartView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            chartView.widthAnchor.constraint(equalToConstant: size),
            chartView.heightAnchor.constraint(equalToConstant: size),
            
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.topAnchor.constraint(equalTo: chartView.bottomAnchor, constant: 20)
        ])
    }
    
    @objc func randomSections() {
        let sections = (0..<8)
            .map({ v in ChartSection(value: Double(v+1), color: UIColor.random) })
            .sorted(by: {$0.value > $1.value })
        
        chartView.setSections(sections, animated: true)
    }
}

extension UIColor {
    public static var random: UIColor {
        return .init(hue: .random(in: 0...1), saturation: 1, brightness: 1, alpha: 1)
    }
}
