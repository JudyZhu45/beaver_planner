'use client';

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

interface LoadingScreenProps {
  onLoadingComplete?: () => void;
  minimumLoadTime?: number;
}

export default function LoadingScreen({ 
  onLoadingComplete,
  minimumLoadTime = 2500 
}: LoadingScreenProps) {
  const [progress, setProgress] = useState(0);
  const [isComplete, setIsComplete] = useState(false);
  const [loadingText, setLoadingText] = useState('正在唤醒海狸...');

  const loadingTexts = [
    '正在唤醒海狸...',
    '整理你的时间...',
    '准备智能建议...',
    '即将就绪...'
  ];

  useEffect(() => {
    // Update loading text periodically
    let textIndex = 0;
    const textInterval = setInterval(() => {
      textIndex = (textIndex + 1) % loadingTexts.length;
      setLoadingText(loadingTexts[textIndex]);
    }, 600);

    // Progress animation
    const progressInterval = setInterval(() => {
      setProgress(prev => {
        if (prev >= 100) {
          clearInterval(progressInterval);
          return 100;
        }
        // Non-linear progress for realism
        const increment = Math.random() * 15 + 5;
        return Math.min(prev + increment, 100);
      });
    }, 200);

    // Complete loading after minimum time
    const timer = setTimeout(() => {
      setIsComplete(true);
      setTimeout(() => {
        onLoadingComplete?.();
      }, 500);
    }, minimumLoadTime);

    return () => {
      clearInterval(textInterval);
      clearInterval(progressInterval);
      clearTimeout(timer);
    };
  }, [minimumLoadTime, onLoadingComplete]);

  return (
    <AnimatePresence>
      {!isComplete && (
        <motion.div
          initial={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.5, ease: 'easeInOut' }}
          className="fixed inset-0 z-50 flex flex-col items-center justify-center bg-gradient-to-br from-[#FAF9F6] via-[#F5F3EF] to-[#EDE9E3]"
        >
          {/* Beaver Logo Animation */}
          <motion.div
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ 
              duration: 0.8, 
              ease: [0.34, 1.56, 0.64, 1] // Spring effect
            }}
            className="relative mb-8"
          >
            {/* Outer glow */}
            <motion.div
              animate={{
                scale: [1, 1.2, 1],
                opacity: [0.3, 0.1, 0.3]
              }}
              transition={{
                duration: 2,
                repeat: Infinity,
                ease: 'easeInOut'
              }}
              className="absolute inset-0 rounded-full bg-[#D4A574] blur-xl"
            />
            
            {/* Beaver Icon */}
            <motion.div
              animate={{ 
                rotate: [0, -5, 5, 0],
                y: [0, -5, 0]
              }}
              transition={{
                duration: 2,
                repeat: Infinity,
                ease: 'easeInOut'
              }}
              className="relative text-8xl"
            >
              🦫
            </motion.div>

            {/* Sparkles */}
            {[...Array(3)].map((_, i) => (
              <motion.div
                key={i}
                animate={{
                  scale: [0, 1, 0],
                  opacity: [0, 1, 0],
                  rotate: [0, 180]
                }}
                transition={{
                  duration: 1.5,
                  repeat: Infinity,
                  delay: i * 0.5,
                  ease: 'easeInOut'
                }}
                className="absolute text-2xl"
                style={{
                  top: `${20 + i * 30}%`,
                  left: i % 2 === 0 ? '-20%' : '120%'
                }}
              >
                ✨
              </motion.div>
            ))}
          </motion.div>

          {/* App Name */}
          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3, duration: 0.6 }}
            className="mb-2 text-3xl font-bold text-[#8B6F47]"
          >
            Beaver Planner
          </motion.h1>

          {/* Tagline */}
            <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5, duration: 0.6 }}
            className="mb-8 text-sm text-[#A09080]"
          >
            懂你的时间管家
          </motion.p>

          {/* Loading Text */}
          <motion.p
            key={loadingText}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.3 }}
            className="mb-4 text-sm font-medium text-[#8B6F47]"
          >
            {loadingText}
          </motion.p>

          {/* Progress Bar Container */}
          <div className="w-64 h-2 overflow-hidden rounded-full bg-[#E5E0D8]">
            {/* Progress Fill */}
            <motion.div
              className="h-full rounded-full bg-gradient-to-r from-[#D4A574] via-[#C4956A] to-[#8B6F47]"
              initial={{ width: 0 }}
              animate={{ width: `${progress}%` }}
              transition={{ duration: 0.3, ease: 'easeOut' }}
            />
          </div>

          {/* Progress Percentage */}
          <motion.p
            className="mt-2 text-xs text-[#A09080]"
          >
            {Math.round(progress)}%
          </motion.p>

          {/* Footer Quote */}
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 1, duration: 0.8 }}
            className="absolute bottom-8 text-xs italic text-[#B8A898]"
          >
            "勤劳的海狸，聪明地建造"
          </motion.p>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
