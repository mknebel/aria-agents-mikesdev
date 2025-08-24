/**
 * Cost Optimization and Performance Tracking System
 * Monitors model usage, costs, and performance metrics for intelligent routing decisions
 */

const fs = require('fs');
const path = require('path');

class CostOptimizationTracker {
  constructor(configPath = '/mnt/d/MikesDev/.claude/openrouter-config/model-routing-config.json') {
    this.config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    this.metricsFile = '/mnt/d/MikesDev/.claude/openrouter-config/usage-metrics.json';
    this.loadMetrics();
    
    // Performance thresholds
    this.thresholds = {
      cost_alert: 10.00, // Alert when daily cost exceeds $10
      speed_degradation: 0.5, // Alert when speed drops 50% below target
      error_rate: 0.05, // Alert when error rate exceeds 5%
      quality_score: 0.7 // Alert when quality score drops below 70%
    };
  }

  loadMetrics() {
    try {
      this.metrics = JSON.parse(fs.readFileSync(this.metricsFile, 'utf8'));
    } catch (error) {
      this.metrics = {
        daily_usage: {},
        model_performance: {},
        cost_tracking: {
          daily: {},
          monthly: {},
          total: 0
        },
        optimization_history: [],
        alerts: []
      };
    }
  }

  saveMetrics() {
    fs.writeFileSync(this.metricsFile, JSON.stringify(this.metrics, null, 2));
  }

  trackExecution(taskData) {
    const today = new Date().toISOString().split('T')[0];
    const model = taskData.model_used;
    
    // Initialize daily tracking
    if (!this.metrics.daily_usage[today]) {
      this.metrics.daily_usage[today] = {
        total_tasks: 0,
        total_cost: 0,
        model_usage: {},
        task_types: {},
        avg_quality: 0,
        error_rate: 0
      };
    }

    const dailyMetrics = this.metrics.daily_usage[today];
    dailyMetrics.total_tasks++;
    dailyMetrics.total_cost += taskData.cost;

    // Model usage tracking
    if (!dailyMetrics.model_usage[model]) {
      dailyMetrics.model_usage[model] = {
        count: 0,
        total_cost: 0,
        avg_execution_time: 0,
        success_rate: 0,
        avg_quality: 0
      };
    }

    const modelMetrics = dailyMetrics.model_usage[model];
    modelMetrics.count++;
    modelMetrics.total_cost += taskData.cost;

    // Update cost tracking
    this.metrics.cost_tracking.total += taskData.cost;
    if (!this.metrics.cost_tracking.daily[today]) {
      this.metrics.cost_tracking.daily[today] = 0;
    }
    this.metrics.cost_tracking.daily[today] += taskData.cost;

    this.saveMetrics();
    return taskData;
  }

  generateRecommendations() {
    const recommendations = [];
    const today = new Date().toISOString().split('T')[0];
    const dailyMetrics = this.metrics.daily_usage[today];

    if (!dailyMetrics) {
      return recommendations;
    }

    // Analyze model usage patterns
    Object.entries(dailyMetrics.model_usage).forEach(([model, metrics]) => {
      const modelConfig = this.config.models[model];
      
      // High cost, low performance models
      if (metrics.avg_quality < 0.8 && metrics.total_cost > 1.0) {
        recommendations.push({
          type: 'model_switch',
          priority: 'high',
          message: 'Consider switching from ' + model + ' to a more cost-effective alternative',
          estimated_savings: this.calculatePotentialSavings(model, metrics),
          alternative_models: this.findAlternativeModels(model)
        });
      }
    });

    return recommendations;
  }

  calculatePotentialSavings(currentModel, metrics) {
    const currentModelConfig = this.config.models[currentModel];
    const alternatives = this.findAlternativeModels(currentModel);
    
    if (alternatives.length === 0) return 0;
    
    const avgTokensPerTask = 2000;
    const currentCostPer1k = currentModelConfig.cost_per_1k_input;
    const savingsPerTask = (currentCostPer1k / 1000) * avgTokensPerTask * 0.3; // Estimate 30% savings
    
    return savingsPerTask * metrics.count;
  }

  findAlternativeModels(currentModel) {
    const currentModelConfig = this.config.models[currentModel];
    const alternatives = [];
    
    Object.entries(this.config.models).forEach(([model, config]) => {
      if (model !== currentModel && 
          config.cost_per_1k_input < currentModelConfig.cost_per_1k_input) {
        alternatives.push(model);
      }
    });
    
    return alternatives;
  }

  generatePerformanceReport(days = 7) {
    const report = {
      summary: {
        total_tasks: 0,
        total_cost: 0,
        avg_cost_per_task: 0
      },
      recommendations: this.generateRecommendations(),
      alerts: this.metrics.alerts.slice(-10)
    };

    return report;
  }
}

module.exports = CostOptimizationTracker;
