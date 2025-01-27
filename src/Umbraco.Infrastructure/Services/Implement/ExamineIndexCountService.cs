﻿using System.Linq;
using Examine;
using Umbraco.Cms.Core.Services;

namespace Umbraco.Cms.Infrastructure.Services.Implement
{
    public class ExamineIndexCountService : IExamineIndexCountService
    {
        private readonly IExamineManager _examineManager;

        public ExamineIndexCountService(IExamineManager examineManager)
        {
            _examineManager = examineManager;
        }

        public int GetCount()
        {
            return _examineManager.Indexes.Count();
        }
    }
}
