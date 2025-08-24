/**
 * Task Complexity Analyzer for Intelligent Model Routing
 * Analyzes task descriptions to determine optimal model selection
 */

class TaskComplexityAnalyzer {
  constructor(configPath = '/mnt/d/MikesDev/.claude/openrouter-config/model-routing-config.json') {
    this.config = require(configPath);
    this.complexityWeights = {
      keywords: 0.4,
      length: 0.2,
      technical_terms: 0.3,
      context_requirements: 0.1
    };
  }

  /**
   * Analyze task and return recommended model configuration
   */
  analyzeTask(taskDescription, contextData = {}) {
    const analysis = {
      description: taskDescription,
      complexity_score: this.calculateComplexityScore(taskDescription),
      task_type: this.classifyTaskType(taskDescription),
      performance_profile: this.determinePerformanceProfile(taskDescription, contextData),
      recommended_model: null,
      fallback_models: [],
      estimated_cost: 0,
      estimated_time: 0
    };

    // Get model recommendation
    const modelRecommendation = this.recommendModel(analysis);
    analysis.recommended_model = modelRecommendation.primary;
    analysis.fallback_models = modelRecommendation.fallbacks;
    analysis.estimated_cost = this.estimateCost(analysis.recommended_model, taskDescription);
    analysis.estimated_time = this.estimateTime(analysis.recommended_model, taskDescription);

    return analysis;
  }

  /**
   * Calculate complexity score (1-10)
   */
  calculateComplexityScore(taskDescription) {
    let score = 1;

    // Keyword-based complexity
    const complexKeywords = [
      'architecture', 'design', 'optimize', 'algorithm', 'performance',
      'security', 'scale', 'complex', 'advanced', 'research'
    ];
    
    const simpleKeywords = [
      'create', 'add', 'update', 'delete', 'list', 'show', 'basic',
      'simple', 'form', 'display', 'format'
    ];

    complexKeywords.forEach(keyword => {
      if (taskDescription.toLowerCase().includes(keyword)) {
        score += 2;
      }
    });

    simpleKeywords.forEach(keyword => {
      if (taskDescription.toLowerCase().includes(keyword)) {
        score -= 0.5;
      }
    });

    // Length-based complexity
    if (taskDescription.length > 200) score += 1;
    if (taskDescription.length > 500) score += 1;

    // Technical term density
    const technicalTerms = [
      'microservices', 'kubernetes', 'docker', 'api', 'database',
      'authentication', 'authorization', 'middleware', 'caching',
      'websockets', 'graphql', 'nosql', 'redis', 'elasticsearch'
    ];

    const technicalMatches = technicalTerms.filter(term => 
      taskDescription.toLowerCase().includes(term)
    ).length;
    
    score += technicalMatches * 0.5;

    return Math.min(Math.max(score, 1), 10);
  }

  /**
   * Classify task type based on content analysis
   */
  classifyTaskType(taskDescription) {
    const classifications = this.config.task_classification;
    
    for (const [type, config] of Object.entries(classifications)) {
      const matchCount = config.keywords.filter(keyword =>
        taskDescription.toLowerCase().includes(keyword)
      ).length;
      
      if (matchCount > 0) {
        return type;
      }
    }
    
    return 'moderate_coding'; // default
  }

  /**
   * Determine performance profile needs
   */
  determinePerformanceProfile(taskDescription, contextData) {
    const urgentKeywords = ['urgent', 'asap', 'quick', 'fast', 'immediately'];
    const qualityKeywords = ['production', 'critical', 'secure', 'enterprise'];
    
    if (urgentKeywords.some(k => taskDescription.toLowerCase().includes(k))) {
      return 'speed_critical';
    }
    
    if (qualityKeywords.some(k => taskDescription.toLowerCase().includes(k))) {
      return 'quality_critical';
    }
    
    if (contextData.parallel_execution) {
      return 'speed_critical';
    }
    
    return 'balanced';
  }

  /**
   * Recommend optimal model based on analysis
   */
  recommendModel(analysis) {
    const taskType = this.config.task_classification[analysis.task_type];
    const performanceProfile = this.config.performance_targets[analysis.performance_profile];
    
    // Apply routing rules
    let candidateModels = taskType.preferred_models;
    
    // Filter by performance constraints
    if (analysis.performance_profile === 'speed_critical') {
      candidateModels = candidateModels.filter(modelName => {
        const model = this.config.models[modelName];
        return model && model.tps >= performanceProfile.target_tps;
      });
    }
    
    // If no models meet criteria, use fallbacks
    if (candidateModels.length === 0) {
      candidateModels = taskType.fallback_models;
    }
    
    return {
      primary: candidateModels[0],
      fallbacks: candidateModels.slice(1)
    };
  }

  /**
   * Estimate cost for task execution
   */
  estimateCost(modelName, taskDescription) {
    const model = this.config.models[modelName];
    if (!model) return 0;
    
    // Rough estimation: 1 token ≈ 4 characters
    const estimatedInputTokens = Math.ceil(taskDescription.length / 4) + 500; // base context
    const estimatedOutputTokens = Math.min(estimatedInputTokens * 2, 4000); // estimated output
    
    const inputCost = (estimatedInputTokens / 1000) * model.cost_per_1k_input;
    const outputCost = (estimatedOutputTokens / 1000) * model.cost_per_1k_output;
    
    return inputCost + outputCost;
  }

  /**
   * Estimate execution time
   */
  estimateTime(modelName, taskDescription) {
    const model = this.config.models[modelName];
    if (!model) return 60;
    
    const estimatedTokens = Math.ceil(taskDescription.length / 4) * 2; // input + output
    const timeInSeconds = estimatedTokens / model.tps;
    
    return Math.max(timeInSeconds, 5); // minimum 5 seconds
  }

  /**
   * Get cost comparison across models
   */
  getCostComparison(taskDescription) {
    const comparison = {};
    
    Object.keys(this.config.models).forEach(modelName => {
      comparison[modelName] = {
        cost: this.estimateCost(modelName, taskDescription),
        time: this.estimateTime(modelName, taskDescription),
        tps: this.config.models[modelName].tps
      };
    });
    
    return comparison;
  }

  /**
   * Batch analyze multiple tasks for parallel execution
   */
  batchAnalyze(tasks) {
    return tasks.map(task => {
      const analysis = this.analyzeTask(task.description, {
        parallel_execution: true,
        priority: task.priority || 5
      });
      
      return {
        ...task,
        analysis: analysis,
        optimized_agent_type: this.getOptimizedAgentType(task.agent_type, analysis)
      };
    });
  }

  /**
   * Get optimized agent type based on model recommendation
   */
  getOptimizedAgentType(originalAgentType, analysis) {
    const modelName = analysis.recommended_model;
    
    // Map models to optimized agent variants
    const modelAgentMap = {
      'cerebras_llama3_1_8b': originalAgentType + '_speed',
      'cerebras_llama3_1_70b': originalAgentType + '_balanced',
      'claude_3_5_sonnet': originalAgentType + '_quality',
      'o1_mini': originalAgentType + '_reasoning',
      'gpt_4o_mini': originalAgentType + '_standard'
    };
    
    return modelAgentMap[modelName] || originalAgentType;
  }
}

// CLI usage
if (require.main === module) {
  const analyzer = new TaskComplexityAnalyzer();
  const task = process.argv[2];
  
  if (!task) {
    console.log('Usage: node task-complexity-analyzer.js "task description"');
    process.exit(1);
  }
  
  const analysis = analyzer.analyzeTask(task);
  console.log(JSON.stringify(analysis, null, 2));
}

module.exports = TaskComplexityAnalyzer;
