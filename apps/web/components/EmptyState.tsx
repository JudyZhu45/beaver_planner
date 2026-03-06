'use client';

import { motion } from 'framer-motion';
import { Plus, Calendar, Sparkles } from 'lucide-react';

interface EmptyStateProps {
  type?: 'tasks' | 'calendar' | 'analytics' | 'default';
  onAction?: () => void;
}

const emptyStates = {
  tasks: {
    icon: '🦫',
    title: '今天还没有任务呢',
    description: '海狸已经准备好了，添加第一个任务开始吧！',
    actionText: '添加任务',
    tip: '💡 小贴士：把大任务拆成小步骤，更容易完成哦'
  },
  calendar: {
    icon: '📅',
    title: '日历空空如也',
    description: '规划你的时间，让每一天都充实起来',
    actionText: '创建日程',
    tip: '💡 小贴士：在高效时段安排重要任务'
  },
  analytics: {
    icon: '📊',
    title: '数据还在积累中',
    description: '使用一段时间后，这里会显示你的效率分析',
    actionText: '去添加任务',
    tip: '💡 小贴士：坚持记录，AI 会更懂你'
  },
  default: {
    icon: '🦫',
    title: '这里什么都没有',
    description: '海狸帮你整理一切，从这里开始吧',
    actionText: '开始使用',
    tip: '💡 小贴士：好的计划是成功的一半'
  }
};

export default function EmptyState({ type = 'default', onAction }: EmptyStateProps) {
  const state = emptyStates[type];

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6, ease: [0.34, 1.56, 0.64, 1] }}
      className="flex flex-col items-center justify-center px-6 py-12 text-center"
    >
      {/* Illustration */}
      <motion.div
        animate={{
          y: [0, -8, 0],
          rotate: [0, -3, 3, 0]
        }}
        transition={{
          duration: 3,
          repeat: Infinity,
          ease: 'easeInOut'
        }}
        className="relative mb-6"
      >
        {/* Background glow */}
        <div className="absolute inset-0 rounded-full bg-gradient-to-br from-[#D4A574]/20 to-[#8B6F47]/10 blur-2xl" />
        
        {/* Main character */}
        <div className="relative text-7xl">{state.icon}</div>
        
        {/* Floating elements */}
        <motion.div
          animate={{
            y: [0, -10, 0],
            opacity: [0.5, 1, 0.5]
          }}
          transition={{ duration: 2, repeat: Infinity, delay: 0.5 }}
          className="absolute -right-4 top-0 text-2xl"
        >
          ✨
        </motion.div>
        <motion.div
          animate={{
            y: [0, -8, 0],
            opacity: [0.5, 1, 0.5]
          }}
          transition={{ duration: 2.5, repeat: Infinity, delay: 1 }}
          className="absolute -left-4 top-4 text-xl"
        >
          💭
        </motion.div>
      </motion.div>

      {/* Title */}
      <h3 className="mb-2 text-xl font-semibold text-[#5C4A3A]">
        {state.title}
      </h3>

      {/* Description */}
      <p className="mb-6 max-w-xs text-sm leading-relaxed text-[#8B7355]">
        {state.description}
      </p>

      {/* Action Button */}
      <motion.button
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        onClick={onAction}
        className="group flex items-center gap-2 rounded-xl bg-gradient-to-r from-[#D4A574] to-[#C4956A] px-6 py-3 text-sm font-medium text-white shadow-lg shadow-[#D4A574]/30 transition-shadow hover:shadow-xl hover:shadow-[#D4A574]/40"
      >
        <Plus className="h-4 w-4 transition-transform group-hover:rotate-90" />
        {state.actionText}
      </motion.button>

      {/* Tip Box */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.5 }}
        className="mt-8 max-w-xs rounded-lg border border-[#E5DDD3] bg-[#FAF8F5]/80 p-4 backdrop-blur-sm"
      >
        <p className="text-xs leading-relaxed text-[#9A8B7A]">
          {state.tip}
        </p>
      </motion.div>

      {/* Decorative elements */}
      <div className="absolute bottom-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-[#D4A574]/30 to-transparent" />
    </motion.div>
  );
}
